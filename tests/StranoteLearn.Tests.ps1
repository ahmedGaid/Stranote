# Pester 3.x tests for the learn engine: cards, questions, spaced repetition, categories and the CV.
# Run:  Invoke-Pester D:\Projects\Stranote\tests

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here '..\src\Stranote.psm1') -Force -DisableNameChecking
. (Join-Path $here 'StranoteTestHelpers.ps1')

# small helpers: the learn data is plain JSON in the learn dir, so the tests read it as it is stored
function Get-SnTestJson([string]$Name) {
    $p = Join-Path $env:STRANOTE_LEARN_DIR $Name
    if (-not (Test-Path $p)) { return @() }
    $raw = [IO.File]::ReadAllText($p)
    if (-not $raw.Trim()) { return @() }
    return @($raw | ConvertFrom-Json | ForEach-Object { $_ })
}
function Set-SnTestJson([string]$Name, $List) {
    $json = ConvertTo-Json -InputObject @($List) -Depth 8
    [IO.File]::WriteAllText((Join-Path $env:STRANOTE_LEARN_DIR $Name), $json, (New-Object Text.UTF8Encoding $false))
}
function New-SnTestQuestion([string]$Id, [int]$Box = 1, [string]$Due = '') {
    return [pscustomobject]@{
        id = $Id; type = 'blank'; q = "Question $Id"; options = @(); answer = 'answer'; explain = ''
        module = 'General'; tags = @(); taskId = ''; cardId = ''; source = 'manual'
        box = $Box; due = $(if ($Due) { $Due } else { (Get-Date).ToString('yyyy-MM-dd') })
        seen = 0; correct = 0; wrong = 0; hist = ''; lastAt = ''; created = (Get-Date).ToString('yyyy-MM-dd HH:mm')
    }
}

Describe 'Cards (Set-SnCard, Remove-SnCard, Set-SnCardKeep)' {
    It 'needs a topic' {
        $root = New-SnTestEnv
        try { { Set-SnCard -Topic '   ' } | Should Throw 'A card needs a topic.' }
        finally { Remove-SnTestEnv $root }
    }
    It 'keeps a trimmed topic, clean tags and a manual source' {
        $root = New-SnTestEnv
        try {
            $c = Set-SnCard -Topic '  Month end accrual  ' -Fact ' Accrual for the last day ' -Tags @(' AP ', '', 'GL')
            $c.topic | Should Be 'Month end accrual'
            $c.fact | Should Be 'Accrual for the last day'
            (@($c.tags) -join ',') | Should Be 'AP,GL'
            $c.source | Should Be 'manual'
            $c.id | Should Match '^K-[0-9a-f]{8}$'
        } finally { Remove-SnTestEnv $root }
    }
    It 'stores the card and gives it an automatic flash question' {
        $root = New-SnTestEnv
        try {
            $c = Set-SnCard -Topic 'VAT rule' -Fact 'VAT applies to goods' -Tags @('AP')
            $cards = @(Get-SnTestJson 'cards.json')
            $cards.Count | Should Be 1
            $cards[0].id | Should Be $c.id
            $qs = @(Get-SnTestJson 'questions.json')
            $qs.Count | Should Be 1
            $qs[0].q | Should Be 'VAT rule'
            $qs[0].answer | Should Be 'VAT applies to goods'
            $qs[0].source | Should Be 'card'
            $qs[0].cardId | Should Be $c.id
        } finally { Remove-SnTestEnv $root }
    }
    It 'hides an automatic card for good when it is removed' {
        $root = New-SnTestEnv
        try {
            Set-SnTestJson 'cards.json' @([pscustomobject]@{ id = 'A-abc'; topic = 'Auto'; fact = 'f'; source = 'auto'; module = 'General'; tags = @() })
            Remove-SnCard -Id 'A-abc'
            @(Get-SnTestJson 'cards.json').Count | Should Be 0
            (@(Get-SnTestJson 'auto-hidden.json') -join ',') | Should Be 'A-abc'
        } finally { Remove-SnTestEnv $root }
    }
    It 'drops a removed card and its question but keeps other cards' {
        $root = New-SnTestEnv
        try {
            $c = Set-SnCard -Topic 'Manual one' -Fact 'f'
            $other = Set-SnCard -Topic 'Another one' -Fact 'f2'
            Remove-SnCard -Id $c.id
            $cards = @(Get-SnTestJson 'cards.json')
            $cards.Count | Should Be 1
            $cards[0].id | Should Be $other.id
            @(Get-SnTestJson 'auto-hidden.json').Count | Should Be 0
            $qs = @(Get-SnTestJson 'questions.json')
            $qs.Count | Should Be 1
            $qs[0].cardId | Should Be $other.id
        } finally { Remove-SnTestEnv $root }
    }
    It 'keeps a card you keep against the next automatic scan' {
        $root = New-SnTestEnv
        try {
            Set-SnTestJson 'cards.json' @([pscustomobject]@{ id = 'A-keep'; topic = 'Auto'; fact = 'f'; source = 'auto'; module = 'General'; tags = @(); created = '2026-10-20 10:00'; updated = '2026-10-20 10:00' })
            Set-SnCardKeep -Id 'A-keep'
            $cards = @(Get-SnTestJson 'cards.json')
            $cards[0].source | Should Be 'manual'
        } finally { Remove-SnTestEnv $root }
    }
}

Describe 'Questions (Add-SnQuestions)' {
    It 'refuses a question type it does not know' {
        $root = New-SnTestEnv
        try { { Add-SnQuestions -Questions @(@{ type = 'essay'; q = 'What is it?'; answer = 'This' }) } | Should Throw 'must be one of' }
        finally { Remove-SnTestEnv $root }
    }
    It 'refuses a question with no text' {
        $root = New-SnTestEnv
        try { { Add-SnQuestions -Questions @(@{ type = 'blank'; q = '   '; answer = 'x' }) } | Should Throw 'A question has no text.' }
        finally { Remove-SnTestEnv $root }
    }
    It 'refuses an MCQ with less than two options' {
        $root = New-SnTestEnv
        try { { Add-SnQuestions -Questions @(@{ type = 'mcq'; q = 'Pick one'; options = @('only'); answer = 0 }) } | Should Throw 'needs at least 2 options' }
        finally { Remove-SnTestEnv $root }
    }
    It 'refuses an MCQ answer that is not one of the options' {
        $root = New-SnTestEnv
        try { { Add-SnQuestions -Questions @(@{ type = 'mcq'; q = 'Pick one'; options = @('one', 'two'); answer = 5 }) } | Should Throw '0-based index' }
        finally { Remove-SnTestEnv $root }
    }
    It 'refuses a question with no answer' {
        $root = New-SnTestEnv
        try { { Add-SnQuestions -Questions @(@{ type = 'blank'; q = 'Fill it in'; answer = '  ' }) } | Should Throw 'has no answer' }
        finally { Remove-SnTestEnv $root }
    }
    It 'takes the answer of an MCQ as a number and keeps the options' {
        $root = New-SnTestEnv
        try {
            $r = Add-SnQuestions -Questions @(@{ type = 'mcq'; q = 'Pick one'; options = @('one', 'two'); answer = '1' })
            $r.added | Should Be 1
            $q = @(Get-SnTestJson 'questions.json')[0]
            $q.answer | Should Be 1
            (@($q.options) -join ',') | Should Be 'one,two'
        } finally { Remove-SnTestEnv $root }
    }
    It 'reads a true/false answer as a yes or a no' {
        $root = New-SnTestEnv
        try {
            Add-SnQuestions -Questions @(@{ type = 'tf'; q = 'Is it true?'; answer = 'yes' }, @{ type = 'tf'; q = 'Is it false?'; answer = 'no' })
            $qs = @(Get-SnTestJson 'questions.json')
            $qs[0].answer | Should Be $true
            $qs[1].answer | Should Be $false
        } finally { Remove-SnTestEnv $root }
    }
    It 'starts every new question in box 1, due today' {
        $root = New-SnTestEnv
        try {
            Add-SnQuestions -Questions @(@{ type = 'blank'; q = 'Fill it in'; answer = 'x'; taskId = 't-0007' }) -Module 'GL'
            $q = @(Get-SnTestJson 'questions.json')[0]
            $q.box | Should Be 1
            $q.seen | Should Be 0
            $q.correct | Should Be 0
            $q.due | Should Be (Get-Date).ToString('yyyy-MM-dd')
            $q.taskId | Should Be 'T-0007'
            $q.module | Should Be 'GL'
            $q.source | Should Be 'claude'
        } finally { Remove-SnTestEnv $root }
    }
}

Describe 'Spaced repetition (Submit-SnAnswer)' {
    It 'refuses an answer for a question that does not exist' {
        $root = New-SnTestEnv
        try { { Submit-SnAnswer -Id 'Q-nope' -Correct $true } | Should Throw 'not found' }
        finally { Remove-SnTestEnv $root }
    }
    It 'moves a correct answer one box up and pushes the due date out' {
        $root = New-SnTestEnv
        try {
            Set-SnTestJson 'questions.json' @(New-SnTestQuestion 'Q-1' 1)
            $q = Submit-SnAnswer -Id 'Q-1' -Correct $true
            $q.box | Should Be 2
            $q.due | Should Be (Get-Date).AddDays(3).ToString('yyyy-MM-dd')
            $q.seen | Should Be 1
            $q.correct | Should Be 1
            $q.wrong | Should Be 0
            $q.hist | Should Be '1'
        } finally { Remove-SnTestEnv $root }
    }
    It 'sends a forgotten question back to box 1 and to tomorrow' {
        $root = New-SnTestEnv
        try {
            Set-SnTestJson 'questions.json' @(New-SnTestQuestion 'Q-2' 4)
            $q = Submit-SnAnswer -Id 'Q-2' -Correct $false
            $q.box | Should Be 1
            $q.due | Should Be (Get-Date).AddDays(1).ToString('yyyy-MM-dd')
            $q.wrong | Should Be 1
            $q.lapses | Should Be 1
        } finally { Remove-SnTestEnv $root }
    }
    It 'treats an again answer as a forgotten one' {
        $root = New-SnTestEnv
        try {
            Set-SnTestJson 'questions.json' @(New-SnTestQuestion 'Q-3' 3)
            $q = Submit-SnAnswer -Id 'Q-3' -Grade 'again'
            $q.box | Should Be 1
            $q.wrong | Should Be 1
        } finally { Remove-SnTestEnv $root }
    }
    It 'keeps the box of a hard answer' {
        $root = New-SnTestEnv
        try {
            Set-SnTestJson 'questions.json' @(New-SnTestQuestion 'Q-4' 3)
            $q = Submit-SnAnswer -Id 'Q-4' -Grade 'hard'
            $q.box | Should Be 3
            $q.due | Should Be (Get-Date).AddDays(7).ToString('yyyy-MM-dd')
        } finally { Remove-SnTestEnv $root }
    }
    It 'jumps two boxes for an easy answer and stops at box 5' {
        $root = New-SnTestEnv
        try {
            Set-SnTestJson 'questions.json' @(New-SnTestQuestion 'Q-5' 2)
            (Submit-SnAnswer -Id 'Q-5' -Grade 'easy').box | Should Be 4
            Set-SnTestJson 'questions.json' @(New-SnTestQuestion 'Q-6' 4)
            (Submit-SnAnswer -Id 'Q-6' -Grade 'easy').box | Should Be 5
        } finally { Remove-SnTestEnv $root }
    }
    It 'does not move a question that was not due yet when it is a surprise' {
        $root = New-SnTestEnv
        try {
            $due = (Get-Date).AddDays(5).ToString('yyyy-MM-dd')
            Set-SnTestJson 'questions.json' @(New-SnTestQuestion 'Q-7' 3 $due)
            $q = Submit-SnAnswer -Id 'Q-7' -Correct $true -Surprise
            $q.box | Should Be 3
            $q.due | Should Be $due
            $q.correct | Should Be 1
        } finally { Remove-SnTestEnv $root }
    }
    It 'keeps only the last 12 answers in the history' {
        $root = New-SnTestEnv
        try {
            $q = New-SnTestQuestion 'Q-8' 1
            $q | Add-Member -NotePropertyName hist -NotePropertyValue '1111111111111' -Force
            Set-SnTestJson 'questions.json' @($q)
            (Submit-SnAnswer -Id 'Q-8' -Correct $false).hist | Should Be '111111111110'
        } finally { Remove-SnTestEnv $root }
    }
}

Describe 'Category rules (Get-CardAutoCategory)' {
    InModuleScope Stranote {
        It 'takes the rule of the kind of the card first' {
            $s = [pscustomobject]@{ knowledge = [pscustomobject]@{
                categories = @('Technical', 'Financial', 'Business')
                byKind = [pscustomobject]@{ api = 'Technical' }
                areaCategory = [pscustomobject]@{ GL = 'Financial' }
                defaultCategory = 'Business' } }
            Get-CardAutoCategory ([pscustomobject]@{ kind = 'api'; module = 'GL' }) $s | Should Be 'Technical'
        }
        It 'then the category of the area of the card' {
            $s = [pscustomobject]@{ knowledge = [pscustomobject]@{
                categories = @('Technical', 'Financial', 'Business')
                byKind = [pscustomobject]@{ api = 'Technical' }
                areaCategory = [pscustomobject]@{ GL = 'Financial' }
                defaultCategory = 'Business' } }
            Get-CardAutoCategory ([pscustomobject]@{ kind = 'answer'; module = 'GL' }) $s | Should Be 'Financial'
        }
        It 'then the default category of the pack' {
            $s = [pscustomobject]@{ knowledge = [pscustomobject]@{
                categories = @('Technical', 'Financial', 'Business')
                byKind = [pscustomobject]@{}
                areaCategory = [pscustomobject]@{}
                defaultCategory = 'Business' } }
            Get-CardAutoCategory ([pscustomobject]@{ kind = 'other'; module = 'XX' }) $s | Should Be 'Business'
        }
        It 'falls back to the kind when the pack has no default category' {
            $s = [pscustomobject]@{ knowledge = [pscustomobject]@{
                categories = @('Technical', 'Financial', 'Business')
                byKind = [pscustomobject]@{}
                areaCategory = [pscustomobject]@{}
                defaultCategory = '' } }
            Get-CardAutoCategory ([pscustomobject]@{ kind = 'decision'; module = 'XX' }) $s | Should Be 'Business'
        }
        It 'falls back to the first category of the pack when nothing else fits' {
            $s = [pscustomobject]@{ knowledge = [pscustomobject]@{
                categories = @('Technical', 'Financial', 'Business')
                byKind = [pscustomobject]@{}
                areaCategory = [pscustomobject]@{}
                defaultCategory = '' } }
            Get-CardAutoCategory ([pscustomobject]@{ kind = 'other'; module = 'XX' }) $s | Should Be 'Technical'
        }
    }
}

Describe 'Card categories (Set-SnCardCategory)' {
    It 'refuses a category the settings do not have' {
        $root = New-SnTestEnv
        try { { Set-SnCardCategory -Id 'K-1' -Category 'Nope' } | Should Throw 'Category must be one of' }
        finally { Remove-SnTestEnv $root }
    }
    It 'remembers the category you chose for a card' {
        $root = New-SnTestEnv
        try {
            (Set-SnCardCategory -Id 'K-1' -Category 'General') | Should Be 'General'
            $ov = @(Get-SnTestJson 'categories.json')[0]
            "$($ov.'K-1')" | Should Be 'General'
        } finally { Remove-SnTestEnv $root }
    }
    It 'keeps the categories of other cards' {
        $root = New-SnTestEnv
        try {
            Set-SnCardCategory -Id 'K-1' -Category 'General'
            Set-SnCardCategory -Id 'K-2' -Category 'General'
            $ov = @(Get-SnTestJson 'categories.json')[0]
            "$($ov.'K-1')" | Should Be 'General'
            "$($ov.'K-2')" | Should Be 'General'
        } finally { Remove-SnTestEnv $root }
    }
}

Describe 'CV (Get-SnCv, Add-SnCvBullet)' {
    It 'starts with empty lists when there is no CV yet' {
        $root = New-SnTestEnv
        try {
            $cv = Get-SnCv
            @($cv.skills).Count | Should Be 0
            @($cv.bullets).Count | Should Be 0
            @($cv.dismissed).Count | Should Be 0
        } finally { Remove-SnTestEnv $root }
    }
    It 'adds a bullet with a trimmed text and its own id' {
        $root = New-SnTestEnv
        try {
            $cv = Add-SnCvBullet -Text '  Fixed the month end accrual  ' -Company 'ACME'
            $b = @($cv.bullets)[0]
            $b.text | Should Be 'Fixed the month end accrual'
            $b.company | Should Be 'ACME'
            $b.id | Should Match '^B-[0-9a-f]{8}$'
            @((Get-SnCv).bullets).Count | Should Be 1
        } finally { Remove-SnTestEnv $root }
    }
    It 'drops a bullet with no text' {
        $root = New-SnTestEnv
        try {
            $cv = Add-SnCvBullet -Text '   ' -Company 'ACME'
            @($cv.bullets).Count | Should Be 0
        } finally { Remove-SnTestEnv $root }
    }
    It 'keeps the bullets it already had' {
        $root = New-SnTestEnv
        try {
            Add-SnCvBullet -Text 'First one' -Company 'ACME' | Out-Null
            $cv = Add-SnCvBullet -Text 'Second one' -Company 'ACME'
            @($cv.bullets).Count | Should Be 2
            @($cv.bullets)[1].text | Should Be 'Second one'
        } finally { Remove-SnTestEnv $root }
    }
}
