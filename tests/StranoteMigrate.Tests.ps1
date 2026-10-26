# Pester 3.x tests: migrating an existing EBS install to profile + pack + overrides loses nothing.
# Uses tests\fixtures\ebs-legacy (anonymised, same shape as a real install) in a throw-away copy.

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here '..\src\Stranote.psm1') -Force -DisableNameChecking
. (Join-Path $here 'StranoteTestHelpers.ps1')
$fixture = Join-Path $here 'fixtures\ebs-legacy'

Describe 'Migration of an existing EBS install' {
    $root = New-SnTestEnv -Fixture $fixture
    try {
        $work = Join-Path $root 'work'; $legacyPath = Join-Path $root 'tool\settings.json'
        $legacy = [IO.File]::ReadAllText($legacyPath) | ConvertFrom-Json
        $before = Get-SnSnapshot -Root $work
        $plan = Invoke-SnMigration -LegacySettingsPath $legacyPath -WhatIf
        It '-WhatIf only reports what it would do' {
            $plan.status | Should Be 'planned'
            Test-Path (Join-Path $env:STRANOTE_LEARN_DIR 'profile.json') | Should Be $false
        }
        $r = Invoke-SnMigration -LegacySettingsPath $legacyPath
        It 'migrates to the oracle-ebs-technical pack and takes a backup first' {
            $r.status | Should Be 'migrated'
            (Get-SnProfile).roles[0].packId | Should Be 'oracle-ebs-technical'
            (Get-SnProfile).roles[0].companies -join ',' | Should Be 'Acme'
            Test-Path (Join-Path $r.backup 'settings.json') | Should Be $true
            Test-Path (Join-Path $r.backup 'questions.json') | Should Be $true
        }
        It 'keeps only your own changes as overrides' {
            ($r.overrides | Sort-Object) -join ',' | Should Be 'appearance,career,types'
        }
        It 'gives exactly the same effective settings as before (except pack-owned knowledge and settings added later)' {
            $a = Copy-SnJson $legacy; $b = Copy-SnJson (Get-SnSettings)
            $a.PSObject.Properties.Remove('knowledge'); $b.PSObject.Properties.Remove('knowledge')
            $b.attachmentsPath | Should Be '{ticket}\01_Requirements\Attachments'   # new since the old file: comes from the pack
            foreach ($n in @($b.PSObject.Properties.Name)) { if (@($a.PSObject.Properties.Name) -notcontains $n) { $b.PSObject.Properties.Remove($n) } }
            ConvertTo-SnCanonicalJson $b | Should Be (ConvertTo-SnCanonicalJson $a)
            (Get-SnSettings).knowledge.categories -join ',' | Should Be 'Technical,Financial,Business,SCM'
        }
        It 'does not change any task or learning file' {
            @(Compare-SnSnapshot $before (Get-SnSnapshot -Root $work)).Count | Should Be 0
        }
        It 'is a no-op the second time' {
            (Invoke-SnMigration -LegacySettingsPath $legacyPath).status | Should Be 'already-migrated'
        }
        It 'extracts exactly the same automatic knowledge as the old code (same ids, topics, facts, questions)' {
            $exp = [IO.File]::ReadAllText((Join-Path $fixture 'expected-auto-knowledge.json')) | ConvertFrom-Json
            $t = Get-SnTaskList | Where-Object { $_.id -eq 'T-0001' }
            $k = & (Get-Module Stranote) { param($t) Get-AutoKnowledge $t 'XXCUST' } $t
            $got = @($k.cards | ForEach-Object { $c = Copy-SnJson $_; $c.PSObject.Properties.Remove('updated'); $c })
            ConvertTo-SnCanonicalJson $got | Should Be (ConvertTo-SnCanonicalJson @($exp.cards))
            # same question ids, answers and cards; the text is compared separately (see next test)
            $noQ = { param($list) @($list | ForEach-Object { $c = Copy-SnJson $_; $c.PSObject.Properties.Remove('q'); $c }) }
            ConvertTo-SnCanonicalJson (& $noQ $k.questions) | Should Be (ConvertTo-SnCanonicalJson (& $noQ $exp.questions))
        }
        It 'fixes the old question text that dropped the procedure name' {
            # old code: "Which package provides $proc? ..." - PowerShell read `$proc?` as a variable named 'proc?'
            $t = Get-SnTaskList | Where-Object { $_.id -eq 'T-0001' }
            $k = & (Get-Module Stranote) { param($t) Get-AutoKnowledge $t 'XXCUST' } $t
            $q = @($k.questions | Where-Object { $_.answer -eq 'FND_FILE' })[0]
            $q.q | Should Match '^Which package provides (LOG|PUT_LINE)\? \(you used it in T-0001'
        }
        It 'keeps card categories the same as before' {
            $s = Get-SnSettings
            $cat = { param($c) & (Get-Module Stranote) { param($c, $s) Get-CardAutoCategory $c $s } $c $s }
            & $cat ([pscustomobject]@{ module = 'GL'; kind = 'answer' }) | Should Be 'Business'
            & $cat ([pscustomobject]@{ module = 'GL'; kind = 'task' }) | Should Be 'Financial'
            & $cat ([pscustomobject]@{ module = 'INV'; kind = 'task' }) | Should Be 'SCM'
            & $cat ([pscustomobject]@{ module = 'FND'; kind = 'task' }) | Should Be 'Technical'
        }
    } finally { Remove-SnTestEnv $root }
}

Describe 'Migration rolls back when something is wrong' {
    $root = New-SnTestEnv -Fixture $fixture
    try {
        It 'leaves no profile behind if the pack is missing' {
            { Invoke-SnMigration -LegacySettingsPath (Join-Path $root 'tool\settings.json') -PackId 'no-such-pack' } | Should Throw
            Test-Path (Join-Path $env:STRANOTE_LEARN_DIR 'profile.json') | Should Be $false
        }
        It 'does nothing when there is no old settings file' {
            (Invoke-SnMigration -LegacySettingsPath (Join-Path $root 'nope.json')).status | Should Be 'nothing-to-migrate'
        }
    } finally { Remove-SnTestEnv $root }
}
