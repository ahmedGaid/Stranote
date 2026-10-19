# Pester 3.x tests for career packs and effective settings.  Run:  Invoke-Pester D:\Projects\Stranote\tests

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here '..\src\Stranote.psm1') -Force -DisableNameChecking
. (Join-Path $here 'StranoteTestHelpers.ps1')
$packs = Join-Path $here '..\packs'

function New-MinPack {
    [pscustomobject]@{
        schemaVersion = 1; id = 'test-pack'; name = 'Test'; field = 'Testing'; version = '1.0.0'; levels = @('Junior')
        categories = @([pscustomobject]@{ id = 'Core'; label = 'Core' })
        areas = @([pscustomobject]@{ id = 'A1'; name = 'Area one'; category = 'Core'; taskModule = $true; concepts = @([pscustomobject]@{ id = 'c1'; title = 'One' }) })
        taskTypes = @([pscustomobject]@{ name = 'Case'; questions = @(); openQuestions = @(); checklist = @('Done it'); objects = @() })
        extractors = @([pscustomobject]@{ id = 'terms'; kind = 'term'; pattern = '(?i)\b(?<key>heparin)\b' })
        settings = [pscustomobject]@{ ticketFolders = @('01_Notes') }
    }
}

Describe 'Career pack validation' {
    It 'accepts a minimal valid pack' { (Test-SnPack -Pack (New-MinPack)).ok | Should Be $true }
    It 'accepts every shipped pack' {
        foreach ($f in Get-ChildItem $packs -Filter '*.json') { $r = Test-SnPack -Path $f.FullName; "$($f.Name): $($r.errors -join '; ')" | Should Be "$($f.Name): " }
    }
    It 'rejects a duplicate area id' {
        $p = New-MinPack; $p.areas += [pscustomobject]@{ id = 'A1'; name = 'again'; concepts = @() }
        (Test-SnPack -Pack $p).errors -join ' ' | Should Match 'duplicate'
    }
    It 'rejects an unknown category with the JSON path' {
        $p = New-MinPack; $p.areas[0].category = 'Nope'
        (Test-SnPack -Pack $p).errors -join ' ' | Should Match 'areas\[0\]\.category'
    }
    It 'rejects an invalid regex' {
        $p = New-MinPack; $p.extractors[0].pattern = '(?<key>[unclosed'
        (Test-SnPack -Pack $p).errors -join ' ' | Should Match 'invalid regex'
    }
    It 'rejects a pattern without the required group' {
        $p = New-MinPack; $p.extractors[0].pattern = '(?i)heparin'
        (Test-SnPack -Pack $p).errors -join ' ' | Should Match '\(\?<key>'
    }
    It 'rejects a catastrophically slow pattern' {
        $p = New-MinPack; $p.extractors[0].pattern = '(?<key>(a+)+b)'
        (Test-SnPack -Pack $p).ok | Should Be $false
    }
    It 'rejects unknown top-level fields but allows x- fields' {
        $p = New-MinPack; $p | Add-Member -NotePropertyName arees -NotePropertyValue @()
        (Test-SnPack -Pack $p).errors -join ' ' | Should Match 'arees: unknown field'
        $q = New-MinPack; $q | Add-Member -NotePropertyName 'x-draft' -NotePropertyValue $true
        (Test-SnPack -Pack $q).ok | Should Be $true
    }
    It 'accepts a ui object and rejects any other ui value' {
        $p = New-MinPack; $p | Add-Member -NotePropertyName ui -NotePropertyValue ([pscustomobject]@{ area = 'Unit'; areas = 'Units' })
        (Test-SnPack -Pack $p).ok | Should Be $true
        $q = New-MinPack; $q | Add-Member -NotePropertyName ui -NotePropertyValue 'Unit'
        (Test-SnPack -Pack $q).errors -join ' ' | Should Match 'ui: must be an object'
    }
}

Describe 'Dashboard wording comes from the pack (Constitution I)' {
    It 'has no career-specific words in the template (except the kept X-EBS header and ebsView key)' {
        $tpl = [IO.File]::ReadAllText((Join-Path $here '..\src\dashboard_template.html')).Replace('X-EBS', '').Replace('ebsView', '')
        $hits = @([regex]::Matches($tpl, '(?i)\bEBS\b|Oracle|XXCUST|FND_|AP_INVOICES|GL_INTERFACE|MD0?50|FNDLOAD|PL/SQL') | ForEach-Object { $_.Value })
        $hits -join ', ' | Should Be ''
    }
}

Describe 'Effective settings = engine defaults <- pack <- overrides' {
    $root = New-SnTestEnv
    try {
        $profilePath = Join-Path $env:STRANOTE_LEARN_DIR 'profile.json'
        It 'uses career-neutral engine defaults when there is no profile' {
            (Get-SnSettings).modules -join ',' | Should Be 'General'
        }
        It 'takes modules, task types and categories from the pack once a profile exists' {
            Save-SnProfile -SnProfile ([pscustomobject]@{ schemaVersion = 1; roles = @([pscustomobject]@{ id = 'r1'; packId = 'oracle-ebs-technical' }) }) | Out-Null
            $s = Get-SnSettings
            $s.modules -contains 'GL' | Should Be $true
            @($s.types | ForEach-Object { $_.name }) -contains 'Interface' | Should Be $true
            $s.knowledge.categories -join ',' | Should Be 'Technical,Financial,Business,SCM'
            $s.knowledge.areaCategory.GL | Should Be 'Financial'
        }
        It 'sends the pack wording (ui) to the page in META' {
            $m = Get-SnMeta
            $m.pack.id | Should Be 'oracle-ebs-technical'
            $m.pack.ui.area | Should Be 'Module'
            $m.pack.areaNames.GL | Should Be 'General Ledger'
            $html = Get-SnDashboardHtml
            $html | Should Match '"cvTitle":"Oracle EBS Technical Consultant"'
            # deep skill rules must survive ConvertTo-Json (depth)
            $html | Should Match '"types":\["Report","Interface","Conversion","Extension","Workflow"\]'
        }
        It 'stores only your changes in overrides.json' {
            $s = Get-SnSettings
            $s.career.companies = @([pscustomobject]@{ name = 'Acme'; role = 'Dev'; start = '2026-01-01'; end = '' })
            Save-SnSettings -Settings $s | Out-Null
            $o = Get-SnOverrides
            @($o.PSObject.Properties.Name) -join ',' | Should Be 'career'
            (Get-SnSettings).career.companies[0].name | Should Be 'Acme'
        }
        It 'keeps your overrides when the pack changes' {
            $pdir = Join-Path $env:STRANOTE_LEARN_DIR 'packs'; New-Item -ItemType Directory -Force $pdir | Out-Null
            $pk = [IO.File]::ReadAllText((Join-Path $packs 'oracle-ebs-technical.json')) | ConvertFrom-Json
            $pk.version = '1.1.0'; $pk.settings.commonQuestions = @('A new pack question?')
            [IO.File]::WriteAllText((Join-Path $pdir 'oracle-ebs-technical.json'), ($pk | ConvertTo-Json -Depth 20), (New-Object Text.UTF8Encoding $false))
            $s = Get-SnSettings
            $s.commonQuestions -join '|' | Should Be 'A new pack question?'
            $s.career.companies[0].name | Should Be 'Acme'
        }
        It 'categorises cards from pack rules (kind first, then area)' {
            $s = Get-SnSettings
            & (Get-Module Stranote) { param($s) Get-CardAutoCategory ([pscustomobject]@{ module = 'GL'; kind = 'api' }) $s } $s | Should Be 'Technical'
            & (Get-Module Stranote) { param($s) Get-CardAutoCategory ([pscustomobject]@{ module = 'PO'; kind = 'note' }) $s } $s | Should Be 'SCM'
            & (Get-Module Stranote) { param($s) Get-CardAutoCategory ([pscustomobject]@{ module = 'HR'; kind = '' }) $s } $s | Should Be 'Technical'
        }
    } finally { Remove-SnTestEnv $root }
}

Describe 'Merge helpers' {
    It 'diff then merge gives back the target' {
        $a = [pscustomobject]@{ x = 1; o = [pscustomobject]@{ p = 1; q = @(1, 2) }; keep = 'same' }
        $b = [pscustomobject]@{ x = 2; o = [pscustomobject]@{ p = 1; q = @(1, 2, 3) }; keep = 'same'; extra = 'new' }
        $d = Get-SnDiff $a $b
        @($d.PSObject.Properties.Name) -join ',' | Should Be 'x,o,extra'
        ConvertTo-SnCanonicalJson (Merge-SnObject $a $d) | Should Be (ConvertTo-SnCanonicalJson $b)
    }
    It 'treats key order as equal' {
        Get-SnDiff ([pscustomobject]@{ a = 1; b = 2 }) ([pscustomobject][ordered]@{ b = 2; a = 1 }) | Should Be $null
    }
}
