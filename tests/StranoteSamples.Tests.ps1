# Pester 3.x tests for pack knowledge extractors on sample work files (T037, SC-004).  Run:  Invoke-Pester D:\Projects\Stranote\tests

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here '..\src\Stranote.psm1') -Force -DisableNameChecking
. (Join-Path $here 'StranoteTestHelpers.ps1')
$packsDir = Join-Path $here '..\packs'
$samplesDir = Join-Path $here '..\samples'

function Use-SnTestPack([string]$PackId) {
    Save-SnProfile -SnProfile ([pscustomobject]@{ schemaVersion = 1; roles = @([pscustomobject]@{ id = 'r1'; packId = $PackId }) }) | Out-Null
}
function New-SnSampleTask([string]$Title, [string[]]$Files) {
    # a real task (folder + task.json) holding the given work files
    $t = New-SnTask -Title $Title -NonInteractive 6>$null
    $t = Find-SnTask $t.id
    foreach ($f in $Files) { Copy-Item $f (Join-Path $t._path (Split-Path $f -Leaf)) }
    return $t
}
function Get-SnKnowledgeCards { @(Get-SnLearn).cards | Where-Object { $_.kind -ne 'task' } }

Describe 'Every shipped pack makes knowledge from its samples (SC-004)' {
    foreach ($pf in Get-ChildItem $packsDir -Filter '*.json') {
        $id = $pf.BaseName
        $root = New-SnTestEnv
        try {
            Use-SnTestPack $id
            $files = @(Get-ChildItem (Join-Path $samplesDir $id) -File -ErrorAction SilentlyContinue)
            It "$id has 5 sample work files" { $files.Count | Should Be 5 }
            foreach ($f in $files) { New-SnSampleTask "Sample $($f.BaseName)" @($f.FullName) | Out-Null }
            Sync-SnKnowledge | Out-Null
            $cards = @(Get-SnKnowledgeCards)
            It "$id yields at least 10 knowledge cards from 5 samples (got $($cards.Count))" { $cards.Count -ge 10 | Should Be $true }
            $cats = @((Get-SnSettings).knowledge.categories)
            It "$id puts every card in one of its categories" {
                @($cards | Where-Object { $cats -notcontains $_.category } | ForEach-Object { "$($_.topic)=$($_.category)" }) -join ', ' | Should Be ''
            }
        } finally { Remove-SnTestEnv $root }
    }
}

Describe 'Term extractors' {
    $root = New-SnTestEnv
    try {
        $custom = Join-Path $env:STRANOTE_LEARN_DIR 'packs'
        New-Item -ItemType Directory -Force -Path $custom | Out-Null
        $pack = [pscustomobject]@{
            schemaVersion = 1; id = 'term-test'; name = 'Term test'; field = 'Testing'; version = '1.0.0'; levels = @('Junior')
            categories = @([pscustomobject]@{ id = 'Core'; label = 'Core' }, [pscustomobject]@{ id = 'Meds'; label = 'Meds' })
            categoryRules = [pscustomobject]@{ byKind = [pscustomobject]@{ term = 'Core' }; default = 'Core' }
            areas = @([pscustomobject]@{ id = 'A1'; name = 'Area one'; category = 'Core'; taskModule = $true; concepts = @() })
            taskTypes = @([pscustomobject]@{ name = 'Case'; questions = @(); openQuestions = @(); checklist = @('Done it'); objects = @() })
            extractors = @(
                [pscustomobject]@{ id = 'drugs'; kind = 'term'; files = @('.txt'); pattern = '(?i)\b(?<key>heparin|insulin|morphine)\b'; group = 'Meds'
                                   minCount = 2; maxCards = 1; cardTemplate = [pscustomobject]@{ topic = 'Drug: {key}'; fact = 'In {taskId}: {context}' } })
            settings = [pscustomobject]@{ ticketFolders = @('01_Notes') }
        }
        [IO.File]::WriteAllText((Join-Path $custom 'term-test.json'), ($pack | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding $false))
        Use-SnTestPack 'term-test'
        $work = Join-Path $root 'in'; New-Item -ItemType Directory -Path $work | Out-Null
        [IO.File]::WriteAllLines((Join-Path $work 'shift.txt'), [string[]]@(
            '- Heparin 5000 units given at 08:00', 'heparin rechecked with the APTT', 'Insulin twice', 'insulin again at noon', 'insulin before bed', 'Morphine once'))
        [IO.File]::WriteAllText((Join-Path $work 'ignored.md'), 'morphine morphine morphine')
        $t = New-SnSampleTask 'Drug round' @((Join-Path $work 'shift.txt'), (Join-Path $work 'ignored.md'))
        Sync-SnKnowledge | Out-Null
        $cards = @(Get-SnKnowledgeCards)
        It 'keeps only terms seen minCount times, most used first, up to maxCards' {
            @($cards | ForEach-Object { $_.topic }) -join ',' | Should Be 'Drug: Insulin'
        }
        It 'fills the card template with the key, task id and the first line as context' {
            $cards[0].fact | Should Match ([regex]::Escape("In $($t.id): Insulin twice"))
            $cards[0].fact | Should Match 'shift\.txt'
        }
        It 'uses the extractor group as the card category and tag' {
            $cards[0].category | Should Be 'Meds'
            @($cards[0].tags) -contains 'Meds' | Should Be $true
        }
        It 'makes a flash question for the term card' {
            @(@(Get-SnLearn).questions | Where-Object { $_.cardId -eq $cards[0].id }).Count | Should Be 1
        }
        It 'rejects a group that is not a category id' {
            $p = $pack | ConvertTo-Json -Depth 10 | ConvertFrom-Json; $p.extractors[0].group = 'Nope'
            (Test-SnPack -Pack $p).errors -join ' ' | Should Match 'extractors\[0\]\.group'
        }
    } finally { Remove-SnTestEnv $root }
}
