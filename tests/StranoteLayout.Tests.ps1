# Pester 3.x tests for spec 005: task-type layouts (folders, save places, attachments folder, general lists on/off)
# and file versions (Save-SnFile -VersionOf / -AsNew / -Note, Get-SnFileFamilies).
# Run:  Invoke-Pester D:\Projects\Stranote\tests
# Every test runs on a throw-away work root with a test pack (copy of packs/general.json + a 'Data pull' type with
# its own layout); the guard refuses to run if the config root is not under %TEMP%.

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here '..\src\Stranote.psm1') -Force -DisableNameChecking
. (Join-Path $here 'StranoteTestHelpers.ps1')
$packs = Join-Path $here '..\packs'

function New-LayoutType {
    [pscustomobject]@{
        name = 'Data pull'
        useBaseChecklist = $false; useCommonQuestions = $false
        phases = @(
            [pscustomobject]@{ name = 'Requested'; percent = 10; column = 'Not started' }
            [pscustomobject]@{ name = 'Data sent'; percent = 70; column = 'Review' }
            [pscustomobject]@{ name = 'On Hold'; percent = $null; column = 'On Hold' }
            [pscustomobject]@{ name = 'Done'; percent = 100; column = 'Done' }
        )
        folders = @('01_From_Requester', '02_Scripts', '03_Data')
        attachmentsPath = '{ticket}\01_From_Requester'
        saveTargets = @(
            [pscustomobject]@{ name = 'Query script'; path = '{ticket}\02_Scripts'; prefix = $false; versioned = $true }
            [pscustomobject]@{ name = 'Data sheet'; path = '{ticket}\03_Data'; prefix = $false; versioned = $true }
            [pscustomobject]@{ name = 'From requester'; path = '{ticket}\01_From_Requester'; prefix = $false }
        )
        questions = @(
            [pscustomobject]@{ k = 'need'; q = 'What data is needed'; kind = 'long'; required = $true }
            [pscustomobject]@{ k = 'filters'; q = 'Filters'; kind = 'long'; askIfBlank = 'Which filters?' }
            [pscustomobject]@{ k = 'reqFiles'; q = 'Their files'; kind = 'files' }
        )
        openQuestions = @('Is the source allowed?')
        checklist = @('Need confirmed', 'Data sent')
        objects = @()
    }
}

function Initialize-LayoutEnv {
    $root = New-SnTestEnv
    $cfgRoot = [IO.Path]::GetFullPath((Get-SnConfig).root)
    if (-not $cfgRoot.StartsWith([IO.Path]::GetFullPath($env:TEMP), [StringComparison]::OrdinalIgnoreCase)) {
        throw "Test env is not isolated: config root is '$cfgRoot'. Refusing to write."
    }
    $pk = [IO.File]::ReadAllText((Join-Path $packs 'general.json')) | ConvertFrom-Json
    $pk.id = 'test-layout'
    $pk.taskTypes = @(@($pk.taskTypes) + (New-LayoutType))
    $pdir = Join-Path $env:STRANOTE_LEARN_DIR 'packs'; New-Item -ItemType Directory -Force $pdir | Out-Null
    [IO.File]::WriteAllText((Join-Path $pdir 'test-layout.json'), ($pk | ConvertTo-Json -Depth 20), (New-Object Text.UTF8Encoding $false))
    Save-SnProfile -SnProfile ([pscustomobject]@{ schemaVersion = 1; roles = @([pscustomobject]@{ id = 'r1'; packId = 'test-layout' }) }) | Out-Null
    return $root
}

function Get-LayoutErrors($Type) { & (Get-Module Stranote) { param($t) Get-SnLayoutErrors $t } $Type }
function Get-Family([string]$Name) { & (Get-Module Stranote) { param($n) Get-SnFileFamily $n } $Name }
function Get-Layout($TypeName) { & (Get-Module Stranote) { param($n) $s = Get-SnSettings; Get-SnTypeLayout $s (Get-TypeDef $s $n) } $TypeName }
function Get-Targets($Task) { & (Get-Module Stranote) { param($t) @(Get-SnTaskTargets $t) } $Task }
function New-B64([string]$Text) { [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Text)) }

Describe 'Type layout validation' {
    It 'accepts the layout type and types without layout fields' {
        @(Get-LayoutErrors (New-LayoutType)).Count | Should Be 0
        @(Get-LayoutErrors ([pscustomobject]@{ name = 'Task'; checklist = @('x') })).Count | Should Be 0
    }
    It 'refuses unsafe or duplicate folders, places outside the task folder and non-bool switches' {
        $t = New-LayoutType
        $t.folders = @('01_A', '..\x', '01_a')
        $t.saveTargets = @([pscustomobject]@{ name = 'Out'; path = '04_Knowledge\x' }, [pscustomobject]@{ name = 'V'; path = '{ticket}\x'; versioned = 'yes' }, [pscustomobject]@{ name = ''; path = '{ticket}\y' })
        $t.attachmentsPath = 'C:\x'
        $t.useBaseChecklist = 'no'
        $e = @(Get-LayoutErrors $t) -join ' | '
        $e | Should Match "folder '\.\.\\x' is not a valid relative folder name"
        $e | Should Match 'folders must be unique'
        $e | Should Match "save place 'Out' must start with \{ticket\}"
        $e | Should Match "save place 'V': versioned must be true or false"
        $e | Should Match 'save place 3 has no name'
        $e | Should Match 'attachments folder must start with \{ticket\}'
        $e | Should Match 'useBaseChecklist must be true or false'
    }
    It 'Test-SnPack reports layout errors with the task type path' {
        $pk = [IO.File]::ReadAllText((Join-Path $packs 'general.json')) | ConvertFrom-Json
        $bad = New-LayoutType; $bad.folders = @('C:\x')
        $pk.taskTypes = @(@($pk.taskTypes) + $bad)
        $r = Test-SnPack -Pack $pk
        $r.ok | Should Be $false
        (@($r.errors) -join ' | ') | Should Match "taskTypes\[6\]: Type 'Data pull' folder 'C:\\x'"
    }
    It 'every shipped pack still loads' {
        foreach ($f in Get-ChildItem $packs -Filter '*.json') { $r = Test-SnPack -Path $f.FullName; ((@($r.errors) -join '; ') + "|$($f.Name)") | Should Be "|$($f.Name)" }
    }
}

Describe 'Tasks with and without a type layout' {
    $root = $null
    BeforeEach { $root = Initialize-LayoutEnv }
    AfterEach { Remove-SnTestEnv $root }

    It 'a layout type gets only its folders, its checklist and its questions' {
        $r = New-SnTask -NonInteractive -Id 'D-1' -Title 'Invoices on hold' -Type 'Data pull' -Details @{ need = 'All held invoices' }
        @(Get-ChildItem $r.Folder -Directory | ForEach-Object { $_.Name } | Sort-Object) -join ',' | Should Be '01_From_Requester,02_Scripts,03_Data'
        $t = Find-SnTask 'D-1'
        @($t.checklist | ForEach-Object { $_.item }) -join '|' | Should Be 'Need confirmed|Data sent'
        @($t.questions | ForEach-Object { $_.q }) -join '|' | Should Be 'Is the source allowed?|Which filters?'
    }
    It 'a type without a layout gives the same folders, checklist and questions as before' {
        $r = New-SnTask -NonInteractive -Id 'T-1' -Title 'Plain' -Type 'Task'
        $pk = [IO.File]::ReadAllText((Join-Path $packs 'general.json')) | ConvertFrom-Json
        $type = @($pk.taskTypes | Where-Object { $_.name -eq 'Task' })[0]
        @(Get-ChildItem $r.Folder -Directory | ForEach-Object { $_.Name } | Sort-Object) -join ',' | Should Be ((@($pk.settings.ticketFolders) | Sort-Object) -join ',')
        $t = Find-SnTask 'T-1'
        @($t.checklist | ForEach-Object { $_.item }) -join '|' | Should Be ((@($type.checklist) + @($pk.settings.baseChecklist) | Where-Object { "$_".Trim() }) -join '|')
        @($t.questions | ForEach-Object { $_.q }) -join '|' | Should Be ((@($type.openQuestions) + @($pk.settings.commonQuestions) | Where-Object { "$_".Trim() }) -join '|')
    }
    It 'resolves save places per task: the type places + general places outside the task folder' {
        New-SnTask -NonInteractive -Id 'D-2' -Title 'x' -Type 'Data pull' -Details @{ need = 'x' } | Out-Null
        New-SnTask -NonInteractive -Id 'T-2' -Title 'x' -Type 'Task' | Out-Null
        @(Get-Targets (Find-SnTask 'D-2') | ForEach-Object { $_.name }) -join '|' | Should Be 'Query script|Data sheet|From requester|How-to (Knowledge base)|Template (Knowledge base)|Certificate or admin file'
        $pk = [IO.File]::ReadAllText((Join-Path $packs 'general.json')) | ConvertFrom-Json
        @(Get-Targets (Find-SnTask 'T-2') | ForEach-Object { $_.name }) -join '|' | Should Be (@($pk.settings.saveTargets | ForEach-Object { $_.name }) -join '|')
        (Save-SnFile -Id 'D-2' -Target 3 -FileName 'howto.md' -Text 'x').relative | Should Be '04_Knowledge\HowTo\howto.md'
        (Save-SnFile -Id 'D-2' -Target 2 -FileName 'their.sql' -Text 'x').relative | Should Match 'D-2.*\\01_From_Requester\\their\.sql$'
        { Save-SnFile -Id 'D-2' -Target 6 -FileName 'x.txt' -Text 'x' } | Should Throw 'Unknown save destination'
    }
    It 'attachments of a layout type go to its own folder; others keep the general place' {
        $src = Join-Path $root 'shot.png'; [IO.File]::WriteAllBytes($src, [byte[]](1, 2))
        $r = New-SnTask -NonInteractive -Id 'D-3' -Title 'x' -Type 'Data pull' -Details @{ need = 'x' } -Attach @("reqFiles=$src")
        $r.Attached | Should Be 1
        Test-Path (Join-Path $r.Folder '01_From_Requester\shot.png') | Should Be $true
        (Get-SnTaskFiles -Id 'D-3').attachDir | Should Be '01_From_Requester'
        New-SnTask -NonInteractive -Id 'T-3' -Title 'x' -Type 'Task' | Out-Null
        (Get-SnTaskFiles -Id 'T-3').attachDir | Should Be '01_Notes\Attachments'
    }
    It 'Settings save keeps every layout field and refuses a broken one' {
        Save-SnSettings -Settings (Get-SnSettings) | Out-Null
        Save-SnSettings -Settings (Get-SnSettings) | Out-Null
        $l = Get-Layout 'Data pull'
        @($l.folders) -join ',' | Should Be '01_From_Requester,02_Scripts,03_Data'
        $l.attachmentsPath | Should Be '{ticket}\01_From_Requester'
        $l.useBaseChecklist | Should Be $false
        @($l.saveTargets | Where-Object { $_.versioned -eq $true }).Count | Should Be 2
        $s = Get-SnSettings
        @($s.types | Where-Object { $_.name -eq 'Data pull' })[0].folders = @('..\up')
        { Save-SnSettings -Settings $s } | Should Throw "folder '..\up' is not a valid relative folder name."
    }
    It 'saving settings five times keeps every type and a versioned general place unchanged' {
        $s = Get-SnSettings
        @($s.saveTargets)[1] | Add-Member -NotePropertyName versioned -NotePropertyValue $true -Force
        Save-SnSettings -Settings $s | Out-Null
        $before = ConvertTo-SnCanonicalJson @((Get-SnSettings).types)
        foreach ($i in 1..5) { Save-SnSettings -Settings (Get-SnSettings) | Out-Null }
        ConvertTo-SnCanonicalJson @((Get-SnSettings).types) | Should Be $before
        @((Get-SnSettings).saveTargets)[1].versioned | Should Be $true
        @(@((Get-SnSettings).types | Where-Object { $_.name -eq 'Task' })[0].PSObject.Properties.Name) -contains 'folders' | Should Be $false
    }
    It 'creating folders for active tickets uses each task type layout' {
        $r = New-SnTask -NonInteractive -Id 'D-4' -Title 'x' -Type 'Data pull' -Details @{ need = 'x' }
        Save-SnSettings -Settings (Get-SnSettings) -ApplyToActiveTickets | Out-Null
        Test-Path (Join-Path $r.Folder '01_Notes') | Should Be $false
    }
    It 'sends resolved layouts to the page and keeps plain save places as before' {
        $m = Get-SnMeta
        @($m.typeLayouts['Data pull'].saveTargets)[0].versioned | Should Be $true
        @($m.typeLayouts['Data pull'].folders).Count | Should Be 3
        $m.typeLayouts['Task'].useBaseChecklist | Should Be $true
        @($m.saveTargets[0].PSObject.Properties.Name) -join ',' | Should Be 'name,path,prefix'
    }
}

Describe 'File families and versions' {
    $root = $null
    BeforeEach { $root = Initialize-LayoutEnv }
    AfterEach { Remove-SnTestEnv $root }

    It 'reads family and version from file names' {
        $f = Get-Family 'query.sql'; "$($f.family)|$($f.version)|$($f.ext)" | Should Be 'query|1|.sql'
        $f = Get-Family 'query_v2.sql'; "$($f.family)|$($f.version)" | Should Be 'query|2'
        $f = Get-Family 'report_v7.XLSX'; "$($f.family)|$($f.version)|$($f.ext)" | Should Be 'report|7|.XLSX'
        $f = Get-Family 'a_v2_V3.txt'; "$($f.family)|$($f.version)" | Should Be 'a_v2|3'
        $f = Get-Family '_v2.txt'; "$($f.family)|$($f.version)" | Should Be '_v2|1'
        $f = Get-Family 'v_v0.txt'; "$($f.family)|$($f.version)" | Should Be 'v_v0|1'
    }
    It 'a versioned place names the first file _v1 and a new version _v2 under the family name' {
        New-SnTask -NonInteractive -Id 'V-1' -Title 'x' -Type 'Data pull' -Details @{ need = 'x' } | Out-Null
        $a = Save-SnFile -Id 'V-1' -Target 1 -FileName 'AP_holds.xlsx' -Base64 (New-B64 'one')
        [IO.Path]::GetFileName($a.path) | Should Be 'AP_holds_v1.xlsx'
        $b = Save-SnFile -Id 'V-1' -Target 1 -FileName 'Book1.xlsx' -Base64 (New-B64 'two') -VersionOf 'AP_holds' -Note "added`r`nsupplier site"
        [IO.Path]::GetFileName($b.path) | Should Be 'AP_holds_v2.xlsx'
        "$($b.family)|$($b.version)" | Should Be 'AP_holds|2'
        [IO.File]::ReadAllText($a.path) | Should Be 'one'
        $t = Find-SnTask 'V-1'
        $rec = @($t.files)[-1]
        "$($rec.family)|$($rec.version)|$($rec.note)|$($rec.original)" | Should Be 'AP_holds|2|added supplier site|'
        $rec.follows | Should Be $a.relative
        [IO.File]::ReadAllText((Join-Path $t._path '_NOTES.md')) | Should Match 'AP_holds_v2\.xlsx  \(Data sheet\) \| version 2 of AP_holds \| added supplier site'
    }
    It 'a new version takes the extension of the new file and never overwrites' {
        New-SnTask -NonInteractive -Id 'V-2' -Title 'x' -Type 'Data pull' -Details @{ need = 'x' } | Out-Null
        Save-SnFile -Id 'V-2' -Target 0 -FileName 'q.sql' -Text 'select 1' | Out-Null
        $dir = Join-Path (Find-SnTask 'V-2')._path '02_Scripts'
        [IO.File]::WriteAllText((Join-Path $dir 'q_v3.txt'), 'planted')
        $r = Save-SnFile -Id 'V-2' -Target 0 -FileName 'new.txt' -Text 'select 2' -VersionOf 'Q'
        [IO.Path]::GetFileName($r.path) | Should Be 'q_v4.txt'
        [IO.File]::ReadAllText((Join-Path $dir 'q_v3.txt')) | Should Be 'planted'
    }
    It '-AsNew refuses a taken name; no flag keeps the old free-name rule' {
        New-SnTask -NonInteractive -Id 'V-3' -Title 'x' -Type 'Task' | Out-Null
        Save-SnFile -Id 'V-3' -Target 1 -FileName 'a.txt' -Text '1' | Out-Null
        { Save-SnFile -Id 'V-3' -Target 1 -FileName 'a.txt' -Text '2' -AsNew } | Should Throw "A file named 'a.txt' is already here"
        [IO.Path]::GetFileName((Save-SnFile -Id 'V-3' -Target 1 -FileName 'a.txt' -Text '2').path) | Should Be 'a_v2.txt'
        [IO.Path]::GetFileName((Save-SnFile -Id 'V-3' -Target 1 -FileName 'b.txt' -Text '1' -AsNew).path) | Should Be 'b.txt'
        { Save-SnFile -Id 'V-3' -Target 1 -FileName 'c.txt' -Text '1' -VersionOf 'nothing' } | Should Throw "There is no file 'nothing'"
        { Save-SnFile -Id 'V-3' -Target 1 -FileName 'c.txt' -Text '1' -VersionOf 'a' -AsNew } | Should Throw 'not both'
    }
    It 'lists families newest first, old plain + _v2 names as one family, Arabic names kept' {
        New-SnTask -NonInteractive -Id 'V-4' -Title 'x' -Type 'Task' | Out-Null
        $dir = Join-Path (Find-SnTask 'V-4')._path '02_Files'
        $ar = -join ([char[]](0x062A, 0x0642, 0x0631, 0x064A, 0x0631))
        [IO.File]::WriteAllText((Join-Path $dir 'query.sql'), '1'); (Get-Item (Join-Path $dir 'query.sql')).LastWriteTime = (Get-Date).AddHours(-3)
        [IO.File]::WriteAllText((Join-Path $dir 'query_v2.sql'), '2'); (Get-Item (Join-Path $dir 'query_v2.sql')).LastWriteTime = (Get-Date).AddHours(-2)
        [IO.File]::WriteAllText((Join-Path $dir "$ar.txt"), '3')
        $r = Get-SnFileFamilies -Id 'V-4' -Target 1
        $r.dir | Should Match 'V-4.*\\02_Files$'
        $r.versioned | Should Be $false
        @($r.families).Count | Should Be 2
        $r.families[0].family | Should Be $ar
        "$($r.families[1].family)|$($r.families[1].latest)|$($r.families[1].version)|$($r.families[1].versions)" | Should Be 'query|query_v2.sql|2|2'
        $v = Save-SnFile -Id 'V-4' -Target 1 -FileName 'x.sql' -Text '3' -VersionOf 'query'
        [IO.Path]::GetFileName($v.path) | Should Be 'query_v3.sql'
    }
    It 'lists families of the attachments place and of an empty folder' {
        New-SnTask -NonInteractive -Id 'V-5' -Title 'x' -Type 'Data pull' -Details @{ need = 'x' } | Out-Null
        @((Get-SnFileFamilies -Id 'V-5' -Attachment).families).Count | Should Be 0
        Save-SnFile -Id 'V-5' -Attachment -FileName 'their.sql' -Text 'x' | Out-Null
        $r = Get-SnFileFamilies -Id 'V-5' -Attachment
        $r.dir | Should Match '01_From_Requester$'
        @($r.families).Count | Should Be 1
        (Get-SnFileFamilies -Id 'V-5' -Target 1).versioned | Should Be $true
    }
}

function Get-PhaseErrors($Type, [string[]]$General) { & (Get-Module Stranote) { param($t, $g) Get-SnTypePhaseErrors $t $g } $Type $General }

Describe 'Task-type phases' {
    $general = @('Not started', 'Planning', 'In progress', 'Review', 'On Hold', 'Done')
    It 'accepts the layout type phases and types without phases' {
        @(Get-PhaseErrors (New-LayoutType) $general).Count | Should Be 0
        @(Get-PhaseErrors ([pscustomobject]@{ name = 'Task' }) $general).Count | Should Be 0
    }
    It 'refuses a list without Done, unknown columns, moved Done / On Hold, duplicates and bad percents' {
        $t = [pscustomobject]@{ name = 'X'; phases = @(
                [pscustomobject]@{ name = 'Sent'; percent = 150; column = 'UAT' }
                [pscustomobject]@{ name = 'sent'; column = 'Review' }
                [pscustomobject]@{ name = 'On Hold'; column = 'Review' }
                [pscustomobject]@{ name = 'Ready'; column = '' }) }
        $e = @(Get-PhaseErrors $t $general) -join ' | '
        $e | Should Match "phases must include 'Done'"
        $e | Should Match "phase 'Sent': column 'UAT' is not one of the phases"
        $e | Should Match "phase 'Sent' percent must be 0-100"
        $e | Should Match 'phase names must be unique'
        $e | Should Match "phase 'On Hold' must use the 'On Hold' column"
        $e | Should Match "phase 'Ready' needs a board column"
        $t2 = [pscustomobject]@{ name = 'Y'; phases = @([pscustomobject]@{ name = 'Done'; column = 'Review' }) }
        $e2 = @(Get-PhaseErrors $t2 $general) -join ' | '
        $e2 | Should Match 'needs at least one phase besides Done'
        $e2 | Should Match "phase 'Done' must use the 'Done' column"
    }
    It 'Test-SnPack checks columns against the pack phases' {
        $pk = [IO.File]::ReadAllText((Join-Path $packs 'general.json')) | ConvertFrom-Json
        $bad = New-LayoutType; $bad.phases[1].column = 'UAT'
        $pk.taskTypes = @(@($pk.taskTypes) + $bad)
        (@((Test-SnPack -Pack $pk).errors) -join ' | ') | Should Match "taskTypes\[6\]: Type 'Data pull': phase 'Data sent': column 'UAT'"
    }

    $root = $null
    BeforeEach { $root = Initialize-LayoutEnv }
    AfterEach { Remove-SnTestEnv $root }

    It 'a new task starts in the type first phase and moves only through the type phases' {
        New-SnTask -NonInteractive -Id 'P-1' -Title 'x' -Type 'Data pull' -Details @{ need = 'x' } | Out-Null
        (Find-SnTask 'P-1').phase | Should Be 'Requested'
        Update-SnTask -Id 'P-1' -Phase 'data sent' | Out-Null
        $t = Find-SnTask 'P-1'
        "$($t.phase)|$($t.percent)" | Should Be 'Data sent|70'
        { Update-SnTask -Id 'P-1' -Phase 'Planning' } | Should Throw 'Phase must be one of: Requested, Data sent, On Hold, Done'
    }
    It 'a type without phases keeps the general phases' {
        New-SnTask -NonInteractive -Id 'P-2' -Title 'x' -Type 'Task' | Out-Null
        (Find-SnTask 'P-2').phase | Should Be 'Not started'
        Update-SnTask -Id 'P-2' -Phase 'Review' | Out-Null
        "$((Find-SnTask 'P-2').phase)|$((Find-SnTask 'P-2').percent)" | Should Be 'Review|80'
    }
    It 'a task keeps a phase its type no longer has and can still be updated' {
        New-SnTask -NonInteractive -Id 'P-3' -Title 'x' -Type 'Data pull' -Details @{ need = 'x' } | Out-Null
        Update-SnTask -Id 'P-3' -Phase 'Data sent' | Out-Null
        $s = Get-SnSettings
        $ty = @($s.types | Where-Object { $_.name -eq 'Data pull' })[0]
        $ty.phases = @(@($ty.phases) | Where-Object { $_.name -ne 'Data sent' })
        Save-SnSettings -Settings $s | Out-Null
        (Find-SnTask 'P-3').phase | Should Be 'Data sent'
        Update-SnTask -Id 'P-3' -Note 'still waiting' | Out-Null
        Update-SnTask -Id 'P-3' -Phase 'Data sent' -Note 'kept' | Out-Null
        (Find-SnTask 'P-3').phase | Should Be 'Data sent'
        Update-SnTask -Id 'P-3' -Phase 'Requested' | Out-Null
        (Find-SnTask 'P-3').phase | Should Be 'Requested'
    }
    It 'tells the page each type phases, percents and board columns' {
        $m = Get-SnMeta
        @($m.typeLayouts['Data pull'].phases) -join ',' | Should Be 'Requested,Data sent,On Hold,Done'
        $m.typeLayouts['Data pull'].phaseColumn.'Data sent' | Should Be 'Review'
        $m.typeLayouts['Data pull'].phasePct['Data sent'] | Should Be 70
        $m.typeLayouts['Task'].phaseColumn.'Planning' | Should Be 'Planning'
        @($m.phases) -join ',' | Should Be 'Not started,Planning,In progress,Review,On Hold,Done'
    }
}

Describe 'Shipped EBS technical pack: Data request' {
    $root = New-SnTestEnv
    try {
        Save-SnProfile -SnProfile ([pscustomobject]@{ schemaVersion = 1; roles = @([pscustomobject]@{ id = 'r1'; packId = 'oracle-ebs-technical' }) }) | Out-Null
        $pk = [IO.File]::ReadAllText((Join-Path $packs 'oracle-ebs-technical.json')) | ConvertFrom-Json

        It 'moves through its own short phases, shown in the general board columns' {
            New-SnTask -NonInteractive -Id 'DR-9' -Title 'Phases' -Type 'Data request' -Details @{ need = 'x' } | Out-Null
            (Find-SnTask 'DR-9').phase | Should Be 'Requested'
            Update-SnTask -Id 'DR-9' -Phase 'Data sent' | Out-Null
            "$((Find-SnTask 'DR-9').phase)|$((Find-SnTask 'DR-9').percent)" | Should Be 'Data sent|70'
            { Update-SnTask -Id 'DR-9' -Phase 'Design' } | Should Throw 'Phase must be one of'
            $m = Get-SnMeta
            $m.typeLayouts['Data request'].phaseColumn.'Data sent' | Should Be 'UAT'
            @($m.typeLayouts['Report'].phases) -join ',' | Should Be (@($pk.settings.phases | ForEach-Object { $_.name }) -join ',')
        }
        It 'creates the data folders, its own checklist only and open questions for the gaps' {
            $src = Join-Path $root 'their.sql'; [IO.File]::WriteAllText($src, 'select 1 from dual')
            $r = New-SnTask -NonInteractive -Id 'DR-1' -Title 'Invoices on hold' -Type 'Data request' -Details @{ need = 'All AP invoices on hold' } -Attach @("reqFiles=$src")
            @(Get-ChildItem $r.Folder -Directory | ForEach-Object { $_.Name } | Sort-Object) -join ',' | Should Be '01_From_Requester,02_Scripts,03_Data'
            Test-Path (Join-Path $r.Folder '01_From_Requester\their.sql') | Should Be $true
            $t = Find-SnTask 'DR-1'
            $items = @($t.checklist | ForEach-Object { $_.item })
            $items.Count | Should Be 6
            @($items | Where-Object { @($pk.settings.baseChecklist) -contains $_ }).Count | Should Be 0
            $q = @($t.questions | ForEach-Object { $_.q })
            $q -contains 'Which filters / date range should the data cover?' | Should Be $true
            $q -contains 'Which columns does the requester need?' | Should Be $true
            @($q | Where-Object { @($pk.settings.commonQuestions) -contains $_ }).Count | Should Be 0
        }
        It 'a recurring request asks whether it should become a report' {
            New-SnTask -NonInteractive -Id 'DR-2' -Title 'Monthly holds' -Type 'Data request' -Details @{ need = 'x'; filters = 'OU 1'; columns = 'all'; repeat = 'recurring (may become a report)' } | Out-Null
            $q = @((Find-SnTask 'DR-2').questions | ForEach-Object { $_.q })
            $q -contains 'Will this be needed again: should it become a report (new Report task)?' | Should Be $true
            $q.Count | Should Be 3
        }
        It 'saves the query and the data sheet as versions in their own folders' {
            New-SnTask -NonInteractive -Id 'DR-3' -Title 'Holds' -Type 'Data request' -Details @{ need = 'x' } | Out-Null
            $names = @(Get-Targets (Find-SnTask 'DR-3') | ForEach-Object { $_.name })
            $qi = [array]::IndexOf($names, 'Query script'); $di = [array]::IndexOf($names, 'Data sheet')
            $a = Save-SnFile -Id 'DR-3' -Target $qi -FileName 'AP_holds.sql' -Text 'select 1 from dual'
            $b = Save-SnFile -Id 'DR-3' -Target $qi -FileName 'pasted.sql' -Text 'select 2 from dual' -VersionOf 'AP_holds' -Note 'added supplier site'
            $c = Save-SnFile -Id 'DR-3' -Target $di -FileName 'Book1.xlsx' -Base64 ([Convert]::ToBase64String([byte[]](1, 2)))
            $a.relative | Should Match '\\02_Scripts\\AP_holds_v1\.sql$'
            $b.relative | Should Match '\\02_Scripts\\AP_holds_v2\.sql$'
            $c.relative | Should Match '\\03_Data\\Book1_v1\.xlsx$'
            @($names | Select-Object -Skip 3) -join '|' | Should Be (@($pk.settings.saveTargets | Where-Object { "$($_.path)" -notmatch '^\{ticket\}' } | ForEach-Object { $_.name }) -join '|')
        }
        It 'other EBS types keep the general folders and checklist' {
            $r = New-SnTask -NonInteractive -Id 'IF-1' -Title 'Supplier load' -Type 'Interface'
            @(Get-ChildItem $r.Folder -Directory | ForEach-Object { $_.Name } | Sort-Object) -join ',' | Should Be ((@($pk.settings.ticketFolders) | Sort-Object) -join ',')
            $items = @((Find-SnTask 'IF-1').checklist | ForEach-Object { $_.item })
            ($items | Select-Object -Last (@($pk.settings.baseChecklist).Count)) -join '|' | Should Be (@($pk.settings.baseChecklist) -join '|')
        }
    } finally { Remove-SnTestEnv $root }
}
