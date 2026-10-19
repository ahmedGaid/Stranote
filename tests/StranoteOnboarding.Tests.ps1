# Pester 3.x tests for the first-day onboarding wizard (spec 001, US2: T022-T023).
# Runs in a throw-away work root (StranoteTestHelpers): never touches real data, never registers a scheduled task.

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here '..\src\Stranote.psm1') -Force -DisableNameChecking
. (Join-Path $here 'StranoteTestHelpers.ps1')

function New-Answers([string]$Root) {
    [pscustomobject]@{
        language = 'ar-EG'; style = @('examples', 'analogies'); packId = 'oracle-ebs-technical'; level = 'Mid'; years = 4
        ratings = [pscustomobject]@{ PLSQL = 'expert'; OAF = 'new'; GL = 'basic'; AP = 'comfortable' }
        company = 'Acme'; title = 'Technical Consultant'; start = '2026-10-15'; industry = 'Retail'
        weekend = @('Fri', 'Sat'); workStart = '09:00'; workEnd = '17:00'
        packAnswers = [pscustomobject]@{ prefix = 'XXACME'; ebsVersion = 'R12.2' }
        taskTypes = @('Report', 'Interface', 'Support'); workRoot = $Root
        focusAreas = @('OAF', 'GL'); target = 'Fusion Financials'; dailyMinutes = 20; reviewTime = '08:30'
        neverOnCv = @('client and employer names'); localOnly = @('code'); cvText = 'Five years at SecretClient Ltd writing PL/SQL.'
    }
}
function Get-Concepts { $p = Join-Path $env:STRANOTE_LEARN_DIR 'concepts.json'; if (Test-Path $p) { [IO.File]::ReadAllText($p) | ConvertFrom-Json } else { [pscustomobject]@{} } }

Describe 'Onboarding: state, save and resume' {
    $root = New-SnTestEnv
    try {
        It 'is required when there is no profile and nothing saved' { (Get-SnOnboarding).state | Should Be 'required' }
        It 'saves a step and resumes from it, merging answers' {
            Save-SnOnboarding -Step 1 -Answers ([pscustomobject]@{ language = 'ar-EG' }) | Out-Null
            Save-SnOnboarding -Step 2 -Answers ([pscustomobject]@{ packId = 'oracle-ebs-technical'; level = 'Mid' }) | Out-Null
            $o = Get-SnOnboarding
            $o.state | Should Be 'in-progress'; $o.step | Should Be 2
            $o.answers.language | Should Be 'ar-EG'; $o.answers.level | Should Be 'Mid'
        }
        It 'refuses an unknown career pack at completion' {
            Save-SnOnboarding -Step 2 -Answers ([pscustomobject]@{ packId = 'no-such-pack' }) | Out-Null
            { Complete-SnOnboarding } | Should Throw
            Test-Path (Join-Path $env:STRANOTE_LEARN_DIR 'profile.json') | Should Be $false
        }
    } finally { Remove-SnTestEnv $root }
}

Describe 'Onboarding: completing builds a personal setup' {
    $root = New-SnTestEnv
    try {
        $work = $root
        New-Item -ItemType Directory -Force (Join-Path $work '00_Inbox') | Out-Null
        [IO.File]::WriteAllText((Join-Path $work '00_Inbox\keep.txt'), 'mine')
        Save-SnOnboarding -Step 8 -Answers (New-Answers $work) | Out-Null
        $r = Complete-SnOnboarding -Today '2026-10-22'   # a Thursday
        $prof = Get-SnProfile; $s = Get-SnSettings
        It 'writes the profile (role, level, language, goals, privacy) and marks onboarding done' {
            $prof.roles[0].packId | Should Be 'oracle-ebs-technical'
            $prof.roles[0].level | Should Be 'Mid'
            $prof.roles[0].companies -join ',' | Should Be 'Acme'
            $prof.language.explain | Should Be 'ar-EG'
            $prof.goals.dailyMinutes | Should Be 20
            $prof.privacy.neverOnCv -join ',' | Should Be 'client and employer names'
            $prof.onboarding.state | Should Be 'done'
        }
        It 'writes the career entry, weekend and pack answers into settings' {
            @($s.career.companies | Where-Object { $_.name -eq 'Acme' }).Count | Should Be 1
            ($s.career.companies | Where-Object { $_.name -eq 'Acme' }).start | Should Be '2026-10-15'
            $s.career.weekend -join ',' | Should Be 'Fri,Sat'
            $s.prefix | Should Be 'XXACME'
            $prof.packAnswers.ebsVersion | Should Be 'R12.2'
        }
        It 'keeps only the task types you picked' { @($s.types | ForEach-Object { $_.name }) -join ',' | Should Be 'Report,Interface,Support' }
        It 'creates missing work folders and never overwrites existing files' {
            Test-Path (Join-Path $work '01_Tickets') | Should Be $true
            Test-Path (Join-Path $work '02_Repos') | Should Be $true
            [IO.File]::ReadAllText((Join-Path $work '00_Inbox\keep.txt')) | Should Be 'mine'
        }
        It 'maps self-ratings to concept statuses (expert=known, comfortable=understood, basic=taught, new=new)' {
            $c = Get-Concepts
            $c.'area:PLSQL'.status | Should Be 'known'
            $c.'area:AP'.status | Should Be 'understood'
            $c.'area:GL'.status | Should Be 'taught'
            $c.'area:OAF'.status | Should Be 'new'
        }
        It 'returns the review time for the morning task (it does not register it itself)' { $r.reviewTime | Should Be '08:30' }
        It 'never copies the pasted CV into cv.json' {
            $cv = Join-Path $env:STRANOTE_LEARN_DIR 'cv.json'
            if (Test-Path $cv) { [IO.File]::ReadAllText($cv) | Should Not Match 'SecretClient' }
        }
        It 'builds a first-week plan: goal areas first, new before basic, nothing you rated expert/comfortable' {
            $p = Get-SnPlan
            $areas = @($p.items | ForEach-Object { $_.areaId } | Select-Object -Unique)
            $areas[0] | Should Be 'OAF'; $areas[1] | Should Be 'GL'
            $areas -contains 'PLSQL' | Should Be $false; $areas -contains 'AP' | Should Be $false
        }
        It 'fits the plan into your daily minutes and skips your weekend' {
            $p = Get-SnPlan
            @($p.items | Where-Object { $_.day -eq '2026-10-22' }).Count | Should Be 2     # 20 min = 2 lessons of 10
            @($p.items | Where-Object { $_.day -eq '2026-10-23' -or $_.day -eq '2026-10-24' }).Count | Should Be 0   # Fri, Sat
            $p.items[2].day | Should Be '2026-10-25'
        }
        It 'running onboarding again keeps your data and does not duplicate the company' {
            Restart-SnOnboarding | Out-Null
            (Get-SnOnboarding).state | Should Be 'in-progress'
            (Get-SnOnboarding).answers.company | Should Be 'Acme'
            Complete-SnOnboarding -Today '2026-10-22' | Out-Null
            @((Get-SnSettings).career.companies | Where-Object { $_.name -eq 'Acme' }).Count | Should Be 1
            (Get-SnProfile).onboarding.state | Should Be 'done'
        }
    } finally { Remove-SnTestEnv $root }
}

Describe 'Teach before quiz with onboarding ratings (SC-005)' {
    $root = New-SnTestEnv
    try {
        Save-SnOnboarding -Step 8 -Answers (New-Answers $root) | Out-Null
        Complete-SnOnboarding -Today '2026-10-22' | Out-Null
        $st = (Get-SnTeach).concepts
        It 'a never-seen question in an area you rated expert is quiz-ready' {
            Test-SnQuestionReady -Question ([pscustomobject]@{ id = 'Q-1'; module = 'PLSQL'; seen = 0 }) -Statuses $st | Should Be $true
        }
        It 'a never-seen question in an area you rated new stays locked until taught' {
            Test-SnQuestionReady -Question ([pscustomobject]@{ id = 'Q-2'; module = 'OAF'; seen = 0 }) -Statuses $st | Should Be $false
        }
        It 'basic (taught) is still locked: you get the short lesson and check first' {
            Test-SnQuestionReady -Question ([pscustomobject]@{ id = 'Q-3'; module = 'GL'; seen = 0 }) -Statuses $st | Should Be $false
        }
    } finally { Remove-SnTestEnv $root }
}

Describe 'Onboarding for an existing (migrated) user' {
    $root = New-SnTestEnv
    try {
        Save-SnProfile -SnProfile ([pscustomobject]@{ schemaVersion = 1; roles = @([pscustomobject]@{ id = 'r1'; packId = 'oracle-ebs-technical'; level = ''; companies = @('Acme') })
                language = [pscustomobject]@{ explain = 'ar-EG' }; goals = [pscustomobject]@{ dailyMinutes = 10; reviewTime = '09:00' }
                onboarding = [pscustomobject]@{ state = 'done'; source = 'migration' } }) | Out-Null
        It 'is done, and the answers are pre-filled from what Stranote already knows' {
            $o = Get-SnOnboarding
            $o.state | Should Be 'done'
            $o.answers.packId | Should Be 'oracle-ebs-technical'
            $o.answers.company | Should Be 'Acme'
            $o.answers.reviewTime | Should Be '09:00'
        }
    } finally { Remove-SnTestEnv $root }
}
