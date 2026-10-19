# Pester 3.x tests for the "teach before quiz" layer.  Run:  Invoke-Pester D:\Projects\Stranote\tests
# Uses a throw-away data folder (STRANOTE_LEARN_DIR) so your real knowledge, quiz and progress are never touched.

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here '..\src\Stranote.psm1') -Force -DisableNameChecking

function New-TempLearnDir {
    $d = Join-Path $env:TEMP ('ops-teach-test-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $d | Out-Null
    $env:STRANOTE_LEARN_DIR = $d
    $env:STRANOTE_CONFIG = Join-Path $d 'config.json'   # temp work root too: never touch real tasks
    [IO.File]::WriteAllText($env:STRANOTE_CONFIG, ('{"root":"' + $d.Replace('\','\\') + '","prefix":"XXCUST","nextAutoId":1}'))
    return $d
}
function New-Lesson([string]$Id = 'T-9999') {
    return [pscustomobject]@{
        id = $Id; title = 'Test lesson'; context = 'why'
        concepts = @([pscustomobject]@{
            id = 'c1'; title = 'Concept one'; cardIds = @('K-card1'); questionIds = @('Q-free1')
            why = 'w'; how = 'h'; when = 'n'; analogy = 'a'; example = 'e'
            simpler = @([pscustomobject]@{ analogy = 'a2'; text = 't2'; example = 'e2' })
            check = [pscustomobject]@{ type = 'mcq'; q = 'pick'; options = @('x', 'y'); answer = 1; explain = 'because' }
        })
        practice = @([pscustomobject]@{ type = 'tf'; q = 'true?'; answer = $true; explain = 'yes' })
    }
}

Describe 'Teach before quiz: question readiness' {
    $dir = New-TempLearnDir
    try {
        It 'blocks a never-seen question whose concept was not taught' {
            $q = [pscustomobject]@{ id = 'Q-1'; cardId = 'K-1'; seen = 0 }
            Test-SnQuestionReady -Question $q -Statuses ([pscustomobject]@{}) | Should Be $false
        }
        It 'allows a question already answered before (existing reviews are not interrupted)' {
            $q = [pscustomobject]@{ id = 'Q-2'; cardId = 'K-2'; seen = 3 }
            Test-SnQuestionReady -Question $q -Statuses ([pscustomobject]@{}) | Should Be $true
        }
        It 'allows a question once its card is understood' {
            Set-SnConceptStatus -Keys 'K-3' -Status understood -Source lesson
            $q = [pscustomobject]@{ id = 'Q-3'; cardId = 'K-3'; seen = 0 }
            Test-SnQuestionReady -Question $q -Statuses (Get-SnTeach).concepts | Should Be $true
        }
        It 'allows a question the user marked as already known' {
            Set-SnConceptStatus -Keys 'q:Q-4' -Status known
            $q = [pscustomobject]@{ id = 'Q-4'; cardId = ''; seen = 0 }
            Test-SnQuestionReady -Question $q -Statuses (Get-SnTeach).concepts | Should Be $true
        }
        It 'still blocks when the concept was only taught but not confirmed (needs-help / taught)' {
            Set-SnConceptStatus -Keys 'K-5' -Status needs-help
            $q = [pscustomobject]@{ id = 'Q-5'; cardId = 'K-5'; seen = 0 }
            Test-SnQuestionReady -Question $q -Statuses (Get-SnTeach).concepts | Should Be $false
        }
        It 'never downgrades understood to taught when a lesson is reopened' {
            Set-SnConceptStatus -Keys 'K-6' -Status understood
            Set-SnConceptStatus -Keys 'K-6' -Status taught
            (Get-SnTeach).concepts.'K-6'.status | Should Be 'understood'
        }
        It 'rejects an unknown status' {
            { Set-SnConceptStatus -Keys 'K-7' -Status 'maybe' } | Should Throw
        }
        It 'marks quiz questions ready/not ready in Get-SnLearn' {
            $qs = @(
                [pscustomobject]@{ id = 'Q-a'; type = 'tf'; q = 'a'; answer = $true; cardId = 'K-a'; seen = 0; correct = 0; wrong = 0; box = 1; due = '2000-01-01'; tags = @(); options = @() },
                [pscustomobject]@{ id = 'Q-b'; type = 'tf'; q = 'b'; answer = $true; cardId = 'K-b'; seen = 0; correct = 0; wrong = 0; box = 1; due = '2000-01-01'; tags = @(); options = @() }
            )
            [IO.File]::WriteAllText((Join-Path $dir 'questions.json'), (ConvertTo-Json -InputObject $qs -Depth 5))
            Set-SnConceptStatus -Keys 'K-a' -Status understood
            $l = Get-SnLearn
            (@($l.questions | Where-Object id -eq 'Q-a'))[0].ready | Should Be $true
            (@($l.questions | Where-Object id -eq 'Q-b'))[0].ready | Should Be $false
        }
    } finally { $env:STRANOTE_LEARN_DIR = $null; Remove-Item -Recurse -Force $dir }
}

Describe 'Lessons' {
    $dir = New-TempLearnDir
    try {
        It 'saves a valid lesson' {
            Set-SnLesson -Lesson (New-Lesson) | Should Be 'T-9999'
            (Get-SnTeach).lessons.'T-9999'.concepts[0].title | Should Be 'Concept one'
        }
        It 'refuses a concept without a check question (must teach then check)' {
            $l = New-Lesson 'T-bad'; $l.concepts[0].PSObject.Properties.Remove('check')
            { Set-SnLesson -Lesson $l } | Should Throw
        }
        It 'refuses an mcq check whose answer index is out of range' {
            $l = New-Lesson 'T-bad2'; $l.concepts[0].check.answer = 5
            { Set-SnLesson -Lesson $l } | Should Throw
        }
        It 'refuses an open (ungradable) concept check' {
            $l = New-Lesson 'T-bad3'; $l.concepts[0].check = [pscustomobject]@{ type = 'open'; q = 'explain'; answer = 'x' }
            { Set-SnLesson -Lesson $l } | Should Throw
        }
        It 'refuses duplicate concept ids' {
            $l = New-Lesson 'T-bad4'; $l.concepts = @($l.concepts[0], $l.concepts[0])
            { Set-SnLesson -Lesson $l } | Should Throw
        }
        It 'stores lesson progress and keeps the score when only the step changes' {
            Save-SnLessonProgress -LessonId 'T-9999' -Step 1 -Status 'in-progress' -Score 2 -Total 3 | Out-Null
            Save-SnLessonProgress -LessonId 'T-9999' -Step 2 -Status 'done' | Out-Null
            $p = (Get-SnTeach).progress.'T-9999'
            $p.step | Should Be 2; $p.status | Should Be 'done'; $p.score | Should Be 2
        }
    } finally { $env:STRANOTE_LEARN_DIR = $null; Remove-Item -Recurse -Force $dir }
}

Describe 'Follow-up questions' {
    $dir = New-TempLearnDir
    try {
        It 'records a question and shows it as pending' {
            $f = Add-SnFollowup -Kind question -Target 'T-0001' -Concept 'c1' -Text 'Why intersection?'
            $f.id | Should Match '^F-'
            @(Get-SnPendingFollowups).Count | Should Be 1
        }
        It 'does not duplicate an identical open request' {
            Add-SnFollowup -Kind simpler -Target 'K-1' | Out-Null
            Add-SnFollowup -Kind simpler -Target 'K-1' | Out-Null
            @(Get-SnPendingFollowups | Where-Object kind -eq 'simpler').Count | Should Be 1
        }
        It 'refuses an empty question' {
            { Add-SnFollowup -Kind question -Target 'T-0001' -Text '   ' } | Should Throw
        }
        It 'stores the answer and clears it from pending' {
            $f = @(Get-SnPendingFollowups | Where-Object kind -eq 'question')[0]
            Set-SnFollowupAnswer -Id $f.id -Answer 'Because a value must pass every rule.'
            @(Get-SnPendingFollowups | Where-Object kind -eq 'question').Count | Should Be 0
            (@((Get-SnTeach).followups | Where-Object id -eq $f.id))[0].answer | Should Match 'every rule'
        }
    } finally { $env:STRANOTE_LEARN_DIR = $null; Remove-Item -Recurse -Force $dir }
}
