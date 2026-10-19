# Pester 3.x tests for the daily review (short + long memory).  Run:  Invoke-Pester D:\Projects\Stranote\tests
# Uses a throw-away data folder (STRANOTE_LEARN_DIR) so your real quiz progress is never touched.

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here '..\src\Stranote.psm1') -Force -DisableNameChecking

function New-TempLearnDir {
    $d = Join-Path $env:TEMP ('ops-review-test-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $d | Out-Null
    $env:STRANOTE_LEARN_DIR = $d
    $env:STRANOTE_CONFIG = Join-Path $d 'config.json'   # temp work root too: never touch real tasks
    [IO.File]::WriteAllText($env:STRANOTE_CONFIG, ('{"root":"' + $d.Replace('\','\\') + '","prefix":"XXCUST","nextAutoId":1}'))
    return $d
}
function D([int]$Days) { (Get-Date).AddDays($Days).ToString('yyyy-MM-dd') }
function Q([string]$Id, [int]$Box, [int]$DueIn, [int]$LastDaysAgo, [int]$Seen = 1) {
    [pscustomobject]@{ id = $Id; type = 'tf'; q = $Id; answer = $true; box = $Box; due = (D $DueIn); seen = $Seen; correct = $Seen; wrong = 0
        lastAt = $(if ($LastDaysAgo -ge 0) { (D (-$LastDaysAgo)) + ' 08:00' } else { '' }); cardId = ''; source = 'claude' }
}
function Set-Questions($Dir, $List) { [IO.File]::WriteAllText((Join-Path $Dir 'questions.json'), (ConvertTo-Json -InputObject @($List) -Depth 5), (New-Object Text.UTF8Encoding $false)) }
function Get-Q($Dir, $Id) { @(Get-Content (Join-Path $Dir 'questions.json') -Raw | ConvertFrom-Json) | ForEach-Object { $_ } | Where-Object { $_.id -eq $Id } }

Describe 'Daily review: picking short and long memory' {
    $dir = New-TempLearnDir
    try {
        Set-Questions $dir @(
            (Q 'new1' 1 0 1), (Q 'new2' 2 -1 3),            # due, recent  -> short
            (Q 'old1' 4 0 21),                               # due, older   -> long
            (Q 'sur1' 5 40 20), (Q 'sur2' 4 10 11), (Q 'sur3' 3 3 4),   # not due, old enough -> surprise candidates
            (Q 'fresh' 3 5 1),                               # not due, seen yesterday -> never a surprise
            (Q 'locked' 1 0 -1 0)                            # never practised and not taught -> never shown
        )
        $r = Get-SnDailyReview -Seed 7
        $ids = @($r.items | ForEach-Object { $_.id })
        It 'includes everything that is due, tagged short or long by box' {
            ($r.items | Where-Object { $_.id -eq 'new1' }).reason | Should Be 'short'
            ($r.items | Where-Object { $_.id -eq 'new2' }).reason | Should Be 'short'
            ($r.items | Where-Object { $_.id -eq 'old1' }).reason | Should Be 'long'
        }
        It 'adds surprise questions on old material that is not due yet' {
            @($r.items | Where-Object { $_.reason -eq 'surprise' }).Count | Should Be 3
            @($r.items | Where-Object { $_.reason -eq 'surprise' } | ForEach-Object { $_.id } | Sort-Object) -join ',' | Should Be 'sur1,sur2,sur3'
        }
        It 'never asks something seen in the last 3 days or not taught yet' {
            $ids -contains 'fresh' | Should Be $false
            $ids -contains 'locked' | Should Be $false
        }
        It 'reports the memory split (short / growing / long) and locked count' {
            $r.memory.fresh | Should Be 2; $r.memory.growing | Should Be 2; $r.memory.strong | Should Be 3; $r.memory.locked | Should Be 1
        }
        It 'is repeatable with the same seed' {
            (@((Get-SnDailyReview -Seed 7).items | ForEach-Object { $_.id }) -join ',') | Should Be ($ids -join ',')
        }
        It 'keeps room for surprises when lots are due, and reports what is left' {
            Set-Questions $dir (@(1..15 | ForEach-Object { Q "d$_" 1 0 1 }) + @((Q 'old' 4 30 30)))
            $x = Get-SnDailyReview -Size 10 -Surprise 3 -Seed 1
            @($x.items).Count | Should Be 10
            @($x.items | Where-Object { $_.reason -eq 'surprise' }).Count | Should Be 1
            $x.dueLeft | Should Be 6
        }
    } finally { Remove-Item $dir -Recurse -Force; Remove-Item Env:STRANOTE_LEARN_DIR; Remove-Item Env:STRANOTE_CONFIG -ErrorAction SilentlyContinue }
}

Describe 'Daily review: grading' {
    $dir = New-TempLearnDir
    try {
        Set-Questions $dir @((Q 'a' 4 30 25), (Q 'b' 4 30 25), (Q 'c' 2 0 3), (Q 'd' 2 0 3), (Q 'e' 1 0 1))
        It 'a right surprise answer keeps the schedule (no early promotion)' {
            Submit-SnAnswer -Id a -Grade good -Surprise | Out-Null
            $q = Get-Q $dir 'a'; $q.box | Should Be 4; $q.due | Should Be (D 30); $q.seen | Should Be 2
        }
        It 'a forgotten surprise comes back tomorrow from box 1 and counts a lapse' {
            Submit-SnAnswer -Id b -Grade again -Surprise | Out-Null
            $q = Get-Q $dir 'b'; $q.box | Should Be 1; $q.due | Should Be (D 1); $q.lapses | Should Be 1; $q.hist | Should Be '0'
        }
        It 'hard keeps the box, easy jumps two boxes' {
            Submit-SnAnswer -Id c -Grade hard | Out-Null; (Get-Q $dir 'c').box | Should Be 2; (Get-Q $dir 'c').due | Should Be (D 3)
            Submit-SnAnswer -Id d -Grade easy | Out-Null; (Get-Q $dir 'd').box | Should Be 4; (Get-Q $dir 'd').due | Should Be (D 21)
        }
        It 'the old -Correct form still works' {
            Submit-SnAnswer -Id e -Correct $true | Out-Null; (Get-Q $dir 'e').box | Should Be 2
        }
    } finally { Remove-Item $dir -Recurse -Force; Remove-Item Env:STRANOTE_LEARN_DIR; Remove-Item Env:STRANOTE_CONFIG -ErrorAction SilentlyContinue }
}

Describe 'Daily review: streak and log' {
    $dir = New-TempLearnDir
    try {
        $mk = { param($days) [pscustomobject]@{ days = [pscustomobject]@{} } | ForEach-Object { $l = $_; foreach ($d in $days) { $l.days | Add-Member -NotePropertyName $d -NotePropertyValue ([pscustomobject]@{ n = 1 }) }; $l } }
        $t = [datetime]'2026-10-22'   # Thursday
        It 'counts days in a row ending today' { Get-SnReviewStreak -Log (& $mk @('2026-10-20', '2026-10-21', '2026-10-22')) -Today $t -Weekend @() | Should Be 3 }
        It 'still counts from yesterday when today is not done yet' { Get-SnReviewStreak -Log (& $mk @('2026-10-20', '2026-10-21')) -Today $t -Weekend @() | Should Be 2 }
        It 'a missed work day breaks it' { Get-SnReviewStreak -Log (& $mk @('2026-10-19', '2026-10-21', '2026-10-22')) -Today $t -Weekend @() | Should Be 2 }
        It 'weekend days do not break it' { Get-SnReviewStreak -Log (& $mk @('2026-10-15', '2026-10-18')) -Today ([datetime]'2026-10-18') -Weekend @('Fri', 'Sat') | Should Be 2 }
        It 'Save-SnReviewDay adds up a day and returns the streak' {
            Save-SnReviewDay -Right 3 -Wrong 1 | Out-Null
            $r = Save-SnReviewDay -Right 2 -Wrong 0
            $r.day.n | Should Be 6; $r.day.right | Should Be 5; $r.streak | Should BeGreaterThan 0
            (Get-SnDailyReview).doneToday | Should Be $true
        }
    } finally { Remove-Item $dir -Recurse -Force; Remove-Item Env:STRANOTE_LEARN_DIR; Remove-Item Env:STRANOTE_CONFIG -ErrorAction SilentlyContinue }
}
