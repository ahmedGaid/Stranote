# Pester 3.x tests for spec 004: intake fields (kind/options/required/when/askIfBlank/sub), task-type variants and
# attachments (Save-SnFile -Attachment, New-SnTask -Attach).
# Run:  Invoke-Pester D:\Projects\Stranote\tests
# Every test runs on a throw-away work root with a test pack (copy of packs/general.json + a Report type with a
# New/Fix branch); the guard refuses to run if the config root is not under %TEMP%.

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here '..\src\Stranote.psm1') -Force -DisableNameChecking
. (Join-Path $here 'StranoteTestHelpers.ps1')
$packs = Join-Path $here '..\packs'

function New-IntakeReportType {
    $fix = 'Fix an existing report'
    [pscustomobject]@{
        name = 'Report'
        questions = @(
            [pscustomobject]@{ k = 'mode'; q = 'New report or fix an existing one?'; kind = 'choice'; options = @('New report', $fix); required = $true }
            [pscustomobject]@{ k = 'format'; q = 'Output format'; d = ''; when = [pscustomobject]@{ k = 'mode'; is = 'New report' } }
            [pscustomobject]@{ k = 'rtype'; q = 'Report type'; kind = 'choice'; options = @('Text', 'Layout', 'Other'); when = [pscustomobject]@{ k = 'mode'; is = $fix } }
            [pscustomobject]@{ k = 'layout'; q = 'Layout file name'; when = [pscustomobject]@{ k = 'rtype'; in = @('Layout') } }
            [pscustomobject]@{ k = 'params'; q = 'Parameters that raise the problem'; kind = 'long'; when = [pscustomobject]@{ k = 'mode'; is = $fix }; askIfBlank = 'Which parameter values raise the problem?' }
            [pscustomobject]@{ k = 'wrong'; q = 'What is wrong now'; kind = 'long'; required = $true; when = [pscustomobject]@{ k = 'mode'; is = $fix } }
            [pscustomobject]@{ k = 'problemFiles'; q = 'Files that show the problem'; kind = 'files'; sub = 'Problem'; when = [pscustomobject]@{ k = 'mode'; is = $fix } }
        )
        openQuestions = @('Columns agreed?')
        checklist = @('Program registered')
        objects = @('{base}_NEW')
        variants = @([pscustomobject]@{ when = [pscustomobject]@{ k = 'mode'; is = $fix }
                openQuestions = @('Who can test the fix?'); checklist = @('Reproduced with the same parameters', 'Old vs new output compared'); objects = @('{base}_EXISTING') })
    }
}

function Initialize-IntakeEnv {
    $root = New-SnTestEnv
    $cfgRoot = [IO.Path]::GetFullPath((Get-SnConfig).root)
    if (-not $cfgRoot.StartsWith([IO.Path]::GetFullPath($env:TEMP), [StringComparison]::OrdinalIgnoreCase)) {
        throw "Test env is not isolated: config root is '$cfgRoot'. Refusing to write."
    }
    $pk = [IO.File]::ReadAllText((Join-Path $packs 'general.json')) | ConvertFrom-Json
    $pk.id = 'test-intake'
    $pk.taskTypes = @(@($pk.taskTypes) + (New-IntakeReportType))
    $pk.settings | Add-Member -NotePropertyName attachmentsPath -NotePropertyValue '{ticket}\02_Files\Attachments' -Force
    $pdir = Join-Path $env:STRANOTE_LEARN_DIR 'packs'; New-Item -ItemType Directory -Force $pdir | Out-Null
    [IO.File]::WriteAllText((Join-Path $pdir 'test-intake.json'), ($pk | ConvertTo-Json -Depth 20), (New-Object Text.UTF8Encoding $false))
    Save-SnProfile -SnProfile ([pscustomobject]@{ schemaVersion = 1; roles = @([pscustomobject]@{ id = 'r1'; packId = 'test-intake' }) }) | Out-Null
    return $root
}

function Get-IntakeErrors($Type) { & (Get-Module Stranote) { param($t) Get-SnIntakeErrors $t } $Type }

Describe 'Intake field validation' {
    It 'accepts the Report type with a New/Fix branch' {
        @(Get-IntakeErrors (New-IntakeReportType)).Count | Should Be 0
    }
    It 'accepts plain questions (no new fields)' {
        @(Get-IntakeErrors ([pscustomobject]@{ name = 'Task'; questions = @([pscustomobject]@{ k = 'goal'; q = 'Goal'; d = '' }) })).Count | Should Be 0
    }
    It 'refuses a choice without options, an unknown kind and options on a text question' {
        $t = [pscustomobject]@{ name = 'X'; questions = @(
                [pscustomobject]@{ k = 'a'; q = 'A'; kind = 'choice' }
                [pscustomobject]@{ k = 'b'; q = 'B'; kind = 'date' }
                [pscustomobject]@{ k = 'c'; q = 'C'; options = @('x', 'y') }) }
        $e = @(Get-IntakeErrors $t) -join ' | '
        $e | Should Match "question 'a': a choice needs 2 to 30 options"
        $e | Should Match "question 'b': kind must be one of"
        $e | Should Match "question 'c': options are only for kind 'choice'"
    }
    It 'refuses a condition on a later or unknown question and a value that is not an option' {
        $t = [pscustomobject]@{ name = 'X'; questions = @(
                [pscustomobject]@{ k = 'a'; q = 'A'; when = [pscustomobject]@{ k = 'm'; is = 'x' } }
                [pscustomobject]@{ k = 'm'; q = 'M'; kind = 'choice'; options = @('x', 'y') }
                [pscustomobject]@{ k = 'b'; q = 'B'; when = [pscustomobject]@{ k = 'm'; is = 'z' } }) }
        $e = @(Get-IntakeErrors $t) -join ' | '
        $e | Should Match "question 'a': when.k 'm' is not an earlier choice question"
        $e | Should Match "question 'b': when value 'z' is not an option of 'm'"
    }
    It 'refuses a required or escaping files question and a variant without a condition' {
        $t = [pscustomobject]@{ name = 'X'; questions = @(
                [pscustomobject]@{ k = 'f'; q = 'F'; kind = 'files'; required = $true; sub = '..\out' })
            variants = @([pscustomobject]@{ checklist = @('x') }) }
        $e = @(Get-IntakeErrors $t) -join ' | '
        $e | Should Match 'a files question cannot be required'
        $e | Should Match 'not a valid relative folder name'
        $e | Should Match 'variant 1: when is required'
    }
    It 'refuses conditions more than 2 levels deep' {
        $t = [pscustomobject]@{ name = 'X'; questions = @(
                [pscustomobject]@{ k = 'a'; q = 'A'; kind = 'choice'; options = @('x', 'y') }
                [pscustomobject]@{ k = 'b'; q = 'B'; kind = 'choice'; options = @('x', 'y'); when = [pscustomobject]@{ k = 'a'; is = 'x' } }
                [pscustomobject]@{ k = 'c'; q = 'C'; kind = 'choice'; options = @('x', 'y'); when = [pscustomobject]@{ k = 'b'; is = 'x' } }
                [pscustomobject]@{ k = 'd'; q = 'D'; when = [pscustomobject]@{ k = 'c'; is = 'x' } }) }
        $e = @(Get-IntakeErrors $t) -join ' | '
        $e | Should Match "question 'd': conditions may be at most 2 levels deep"
        $e | Should Not Match "question 'c'"
    }
    It 'reports intake errors with the task type path in Test-SnPack' {
        $pk = [IO.File]::ReadAllText((Join-Path $packs 'general.json')) | ConvertFrom-Json
        $bad = New-IntakeReportType; $bad.questions[0].options = @('only one')
        $pk.taskTypes = @(@($pk.taskTypes) + $bad)
        $r = Test-SnPack -Pack $pk
        $r.ok | Should Be $false
        ($r.errors -join ' | ') | Should Match "taskTypes\[\d+\]: Type 'Report', question 'mode': a choice needs 2 to 30 options"
    }
    It 'every shipped pack still loads' {
        foreach ($f in Get-ChildItem $packs -Filter '*.json') { $r = Test-SnPack -Path $f.FullName; "$($f.Name): $($r.errors -join '; ')" | Should Be "$($f.Name): " }
    }
}

Describe 'New-SnTask with a New/Fix branch' {
    $root = $null
    BeforeEach { $root = Initialize-IntakeEnv }
    AfterEach { Remove-SnTestEnv $root }

    It 'New report: keeps only the new-report answers and the type lists (hidden answers are dropped)' {
        New-SnTask -NonInteractive -Id 'R-1' -Title 'Aging report' -Type 'Report' -Details @{ mode = 'new report'; format = 'Excel'; params = 'p=1' } | Out-Null
        $t = Find-SnTask 'R-1'
        @($t.details | ForEach-Object { "$($_.k)=$($_.a)" }) -join ',' | Should Be 'mode=New report,format=Excel'
        @($t.checklist | ForEach-Object { $_.item }) -contains 'Program registered' | Should Be $true
        @($t.questions | ForEach-Object { $_.q }) -contains 'Columns agreed?' | Should Be $true
        $t.objects[0] | Should Match '_NEW$'
    }
    It 'Fix: uses the variant lists and turns blank askIfBlank questions into open questions' {
        New-SnTask -NonInteractive -Id 'R-2' -Title 'Aging totals wrong' -Type 'Report' -Details @{ mode = 'Fix an existing report'; rtype = 'layout'; layout = 'XXAGING.rtf'; wrong = "Totals double`nfor OU 2"; format = 'PDF' } | Out-Null
        $t = Find-SnTask 'R-2'
        @($t.details | ForEach-Object { $_.k }) -join ',' | Should Be 'mode,rtype,layout,wrong'
        @($t.details | Where-Object { $_.k -eq 'rtype' })[0].a | Should Be 'Layout'
        $items = @($t.checklist | ForEach-Object { $_.item })   # variant items first, then the pack's base checklist
        ($items[0..1] -join '|') | Should Be 'Reproduced with the same parameters|Old vs new output compared'
        $items -contains 'Program registered' | Should Be $false
        $q = @($t.questions | ForEach-Object { $_.q })
        $q -contains 'Who can test the fix?' | Should Be $true
        $q -contains 'Which parameter values raise the problem?' | Should Be $true
        $q -contains 'Columns agreed?' | Should Be $false
        $t.objects[0] | Should Match '_EXISTING$'
        [IO.File]::ReadAllText((Join-Path $t._path '_NOTES.md')) | Should Match "Totals double\r\n  for OU 2"
    }
    It 'refuses a missing required answer before an auto id is used' {
        $before = (Get-SnConfig).nextAutoId
        { New-SnTask -NonInteractive -Title 'No mode' -Type 'Report' } | Should Throw "'New report or fix an existing one?' needs an answer"
        { New-SnTask -NonInteractive -Title 'No wrong' -Type 'Report' -Details @{ mode = 'Fix an existing report' } } | Should Throw "'What is wrong now' needs an answer"
        (Get-SnConfig).nextAutoId | Should Be $before
    }
    It 'refuses a choice answer that is not an option' {
        { New-SnTask -NonInteractive -Id 'R-3' -Title 'Bad' -Type 'Report' -Details @{ mode = 'Maybe' } } | Should Throw "is not one of: New report, Fix an existing report"
    }
    It 'a type without the new fields gives the same task as before' {
        New-SnTask -NonInteractive -Id 'T-1' -Title 'Plain task' -Type 'Task' -Details @{ goal = 'Ship it'; other = 'x' } | Out-Null
        $t = Find-SnTask 'T-1'
        @($t.details | ForEach-Object { "$($_.q)=$($_.a)" }) -join ',' | Should Be 'What needs to be done and why=Ship it,other=x'
        $pk = [IO.File]::ReadAllText((Join-Path $packs 'general.json')) | ConvertFrom-Json
        $type = @($pk.taskTypes | Where-Object { $_.name -eq 'Task' })[0]
        @($t.checklist | ForEach-Object { $_.item }) -join '|' | Should Be ((@($type.checklist) + @($pk.settings.baseChecklist) | Where-Object { "$_".Trim() }) -join '|')
    }
    It 'Settings save keeps choices, conditions, file questions and variants' {
        Save-SnSettings -Settings (Get-SnSettings) | Out-Null
        Save-SnSettings -Settings (Get-SnSettings) | Out-Null
        $r = @((Get-SnSettings).types | Where-Object { $_.name -eq 'Report' })[0]
        @($r.questions[0].options).Count | Should Be 2
        $r.questions[3].when.in[0] | Should Be 'Layout'
        $r.questions[6].sub | Should Be 'Problem'
        @($r.variants).Count | Should Be 1
    }
    It 'refuses to save settings with a broken intake field or attachments folder' {
        $s = Get-SnSettings
        @($s.types | Where-Object { $_.name -eq 'Report' })[0].questions[2].when.is = 'Nope'
        { Save-SnSettings -Settings $s } | Should Throw "when value 'Nope' is not an option of 'mode'"
        $s = Get-SnSettings; $s.attachmentsPath = 'C:\elsewhere'
        { Save-SnSettings -Settings $s } | Should Throw 'must start with {ticket}'
    }
    It 'sends the intake fields to the page and leaves plain questions as before' {
        $m = Get-SnMeta
        @($m.typeQuestions['Report'][0].options).Count | Should Be 2
        $m.typeQuestions['Report'][1].when.k | Should Be 'mode'
        @($m.typeQuestions['Task'][0].PSObject.Properties.Name) -join ',' | Should Be 'k,q,d'
        $m.attachmentsPath | Should Be '{ticket}\02_Files\Attachments'
    }
}

Describe 'Attachments' {
    $root = $null
    BeforeEach { $root = Initialize-IntakeEnv }
    AfterEach { Remove-SnTestEnv $root }

    It 'New-SnTask -Attach copies files into the attachments folder (question files in their sub-folder)' {
        $src = Join-Path $root 'src'; New-Item -ItemType Directory $src | Out-Null
        $a = Join-Path $src 'email.txt'; $b = Join-Path $src 'wrong totals.png'
        [IO.File]::WriteAllText($a, 'mail'); [IO.File]::WriteAllBytes($b, [byte[]](1, 2, 3))
        $r = New-SnTask -NonInteractive -Id 'R-9' -Title 'Fix' -Type 'Report' -Details @{ mode = 'Fix an existing report'; wrong = 'x' } -Attach @($a, "problemFiles=$b")
        $r.Attached | Should Be 2
        @($r.AttachFailed).Count | Should Be 0
        $att = Join-Path $r.Folder '02_Files\Attachments'
        [IO.File]::ReadAllText((Join-Path $att 'email.txt')) | Should Be 'mail'
        (Get-Item (Join-Path $att 'Problem\wrong totals.png')).Length | Should Be 3
        Test-Path $a | Should Be $true
        $t = Find-SnTask 'R-9'
        $f = @($t.files | Where-Object { $_.question -eq 'problemFiles' })[0]
        $f.target | Should Be 'Attachments'
        $f.original | Should Be 'wrong totals.png'
        [IO.File]::ReadAllText((Join-Path $r.Folder '_NOTES.md')) | Should Match 'FILE \| .*Problem\\wrong totals\.png'
    }
    It 'reports a failed file by name and keeps the task and the other files' {
        $ok = Join-Path $root 'ok.txt'; [IO.File]::WriteAllText($ok, 'ok')
        $r = New-SnTask -NonInteractive -Id 'R-8' -Title 'New one' -Type 'Report' -Details @{ mode = 'New report' } -Attach @((Join-Path $root 'missing.txt'), "problemFiles=$ok", $ok)
        $r.Attached | Should Be 1
        (@($r.AttachFailed) -join ' | ') | Should Match 'missing\.txt: File not found'
        (@($r.AttachFailed) -join ' | ') | Should Match "ok\.txt: 'problemFiles' is not a file question shown for these answers"
        Test-Path (Join-Path $r.Folder '02_Files\Attachments\ok.txt') | Should Be $true
        { Find-SnTask 'R-8' } | Should Not Throw
    }
    It 'Save-SnFile -Attachment never overwrites and keeps Arabic names' {
        New-SnTask -NonInteractive -Id 'T-5' -Title 'Plain' -Type 'Task' | Out-Null
        $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('one'))
        $x = Save-SnFile -Id 'T-5' -Attachment -FileName 'shot.png' -Base64 $b64
        $y = Save-SnFile -Id 'T-5' -Attachment -FileName 'shot.png' -Base64 $b64
        [IO.Path]::GetFileName($x.path) | Should Be 'shot.png'
        [IO.Path]::GetFileName($y.path) | Should Be 'shot_v2.png'
        $x.relative | Should Match '02_Files\\Attachments\\shot\.png$'
        $ar = (-join ([char[]](0x062A, 0x0642, 0x0631, 0x064A, 0x0631))) + '.txt'
        $z = Save-SnFile -Id 'T-5' -Attachment -FileName $ar -Base64 $b64
        [IO.Path]::GetFileName($z.path) | Should Be $ar
    }
    It 'uses the default {ticket}\Attachments when the settings have none and a sub-folder when asked' {
        New-SnTask -NonInteractive -Id 'T-6' -Title 'Plain' -Type 'Task' | Out-Null
        $s = Get-SnSettings; $s.attachmentsPath = ''
        Save-SnSettings -Settings $s | Out-Null
        $r = Save-SnFile -Id 'T-6' -Attachment -SubFolder 'Expected' -FileName 'a.txt' -Text 'a'
        $r.relative | Should Match 'T-6.*\\Attachments\\Expected\\a\.txt$'
    }
    It 'refuses a file over the size limit before anything is written' {
        New-SnTask -NonInteractive -Id 'T-7' -Title 'Plain' -Type 'Task' | Out-Null
        & (Get-Module Stranote) { $script:MaxFileBytes = 4 }
        try {
            { Save-SnFile -Id 'T-7' -Attachment -FileName 'big.bin' -Base64 ([Convert]::ToBase64String([byte[]](1, 2, 3, 4, 5))) } | Should Throw 'larger than 50 MB'
            Test-Path (Join-Path (Find-SnTask 'T-7')._path '02_Files\Attachments') | Should Be $false
        } finally { & (Get-Module Stranote) { $script:MaxFileBytes = 50 * 1048576 } }
    }
    It 'refuses a question that is not a files question of the task type' {
        New-SnTask -NonInteractive -Id 'T-8' -Title 'Plain' -Type 'Task' | Out-Null
        { Save-SnFile -Id 'T-8' -Attachment -Question 'goal' -FileName 'a.txt' -Text 'a' } | Should Throw "'goal' is not a file question"
    }
}
