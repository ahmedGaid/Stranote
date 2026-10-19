# StranoteTeach - "teach before quiz" layer for Stranote (adaptive-teacher method).
# Dot-sourced by StranoteCore.ps1 after StranoteLearn.ps1. Data in <learn dir>:
#   lessons.json    { "<lessonId>": lesson }            lessons written by Claude (Set-SnLesson)
#   concepts.json   { "<key>": { status, at, source, misses } }   your understanding per concept
#                   key = card id, 'q:<questionId>' or 'L:<lessonId>:<conceptId>'
#   followups.json  [ { id, kind, target, concept, text, at, answer, example, answeredAt } ]
#   lesson-progress.json { "<lessonId>": { step, status, score, total, at } }
#
# A quiz question is READY (allowed in the quiz) when:
#   - you have answered it before (seen > 0)   -> existing reviews are never interrupted, or
#   - its card or the question itself is 'understood' (explained + you confirmed) or 'known' (you know it already).
# Everything else is taught first.

$script:ConceptStatuses = @('new', 'taught', 'understood', 'known', 'needs-help')
$script:FollowupKinds = @('question', 'simpler', 'lesson')

function Read-TeachObj([string]$Name) {
    $p = Join-Path (Get-LearnDir) $Name
    if (-not (Test-Path $p)) { return [pscustomobject]@{} }
    $raw = [IO.File]::ReadAllText($p); if (-not $raw.Trim()) { return [pscustomobject]@{} }
    return ($raw | ConvertFrom-Json)
}
function Write-TeachObj([string]$Name, $Obj) { Write-Utf8 (Join-Path (Get-LearnDir) $Name) ($Obj | ConvertTo-Json -Depth 12) }
function Get-Prop($o, [string]$k) { if ($null -eq $o) { return $null }; if ($o -is [hashtable]) { return $o[$k] }; return $o.$k }

function Test-SnQuestionReady {
    <# $Statuses = concepts.json object. Returns $true when the question may appear in the quiz. #>
    param([Parameter(Mandatory)]$Question, $Statuses)
    if ([int](Get-Prop $Question 'seen') -gt 0) { return $true }
    # keys: its card, the question itself, and its whole area (self-rating from onboarding: 'area:GL')
    $mod = "$(Get-Prop $Question 'module')".ToUpper()
    foreach ($k in @((Get-Prop $Question 'cardId'), ('q:' + (Get-Prop $Question 'id')), $(if ($mod) { 'area:' + $mod } else { '' }))) {
        if (-not $k -or $k -eq 'q:') { continue }
        $s = Get-Prop (Get-Prop $Statuses $k) 'status'
        if ($s -eq 'understood' -or $s -eq 'known') { return $true }
    }
    return $false
}

function Set-SnConceptStatus {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string[]]$Keys, [Parameter(Mandatory)][string]$Status, [string]$Source = 'explain')
    if ($script:ConceptStatuses -notcontains $Status) { throw "Status must be one of: $($script:ConceptStatuses -join ', ')" }
    $c = Read-TeachObj 'concepts.json'
    foreach ($k in @($Keys | Where-Object { "$_".Trim() })) {
        $old = $c.$k
        $misses = [int](Get-Prop $old 'misses')
        if ($Status -eq 'needs-help' -or $Status -eq 'taught') { $misses++ }
        # never downgrade 'known' / 'understood' to 'taught' just because a lesson was reopened
        if ($Status -eq 'taught' -and @('understood', 'known') -contains (Get-Prop $old 'status')) { continue }
        $c | Add-Member -NotePropertyName $k -NotePropertyValue ([pscustomobject]@{ status = $Status; at = (Get-Now); source = $Source; misses = $misses }) -Force
    }
    Write-TeachObj 'concepts.json' $c
}

function Assert-TeachQuestion($q, [string]$Where) {
    $type = "$(Get-Prop $q 'type')".ToLower()
    if (@('mcq', 'tf', 'open') -notcontains $type) { throw "$Where`: type must be mcq, tf or open." }
    if (-not "$(Get-Prop $q 'q')".Trim()) { throw "$Where`: question text is missing." }
    if ($type -eq 'mcq') {
        $opts = @(Get-Prop $q 'options'); $a = Get-Prop $q 'answer'
        if ($opts.Count -lt 2) { throw "$Where`: mcq needs at least 2 options." }
        if ("$a" -notmatch '^\d+$' -or [int]$a -ge $opts.Count) { throw "$Where`: mcq answer must be the 0-based index of an option." }
    }
    if ($type -eq 'tf' -and "$(Get-Prop $q 'answer')" -notmatch '^(?i:true|false)$') { throw "$Where`: tf answer must be true or false." }
    if ($type -eq 'open' -and -not "$(Get-Prop $q 'answer')".Trim()) { throw "$Where`: open question needs a model answer." }
}

function Set-SnLesson {
    <#
      Saves a lesson (from -Path UTF-8 JSON or -Lesson object). Shape:
      { id, title, taskId?, cardIds?[], level?, context, summary,
        concepts: [ { id, title, cardIds[], questionIds[], prompt?, why, how, when, analogy, example, steps[], code?,
                      simpler: [ { analogy, text, example } ], check: { type mcq|tf, q, options[], answer, explain } } ],
        practice: [ { type mcq|tf|open, q, options[], answer, explain } ] }
    #>
    [CmdletBinding()]
    param([string]$Path, $Lesson)
    if ($Path) { $Lesson = [IO.File]::ReadAllText($Path) | ConvertFrom-Json }
    if (-not $Lesson) { throw 'No lesson given.' }
    $id = "$(Get-Prop $Lesson 'id')".Trim(); if (-not $id) { throw 'Lesson needs an id (task id or card id).' }
    if (-not "$(Get-Prop $Lesson 'title')".Trim()) { throw 'Lesson needs a title.' }
    $concepts = @(Get-Prop $Lesson 'concepts' | Where-Object { $_ })
    if (-not $concepts.Count) { throw 'Lesson needs at least one concept.' }
    $seen = @{}
    for ($i = 0; $i -lt $concepts.Count; $i++) {
        $c = $concepts[$i]; $cid = "$(Get-Prop $c 'id')".Trim()
        if (-not $cid) { throw "Concept $($i + 1) needs an id." }
        if ($seen[$cid]) { throw "Concept id '$cid' is used twice." }; $seen[$cid] = 1
        if (-not "$(Get-Prop $c 'title')".Trim()) { throw "Concept '$cid' needs a title." }
        if (-not "$(Get-Prop $c 'how')".Trim()) { throw "Concept '$cid' needs a 'how' explanation." }
        if (-not (Get-Prop $c 'check')) { throw "Concept '$cid' needs a check question (teach, then check understanding)." }
        Assert-TeachQuestion (Get-Prop $c 'check') "Concept '$cid' check"
        if ("$(Get-Prop (Get-Prop $c 'check') 'type')" -eq 'open') { throw "Concept '$cid' check must be mcq or tf (it is graded in the app)." }
    }
    $pi = 0; foreach ($p in @(Get-Prop $Lesson 'practice' | Where-Object { $_ })) { $pi++; Assert-TeachQuestion $p "Practice $pi" }
    $Lesson | Add-Member -NotePropertyName updated -NotePropertyValue (Get-Now) -Force
    $all = Read-TeachObj 'lessons.json'
    $all | Add-Member -NotePropertyName $id -NotePropertyValue $Lesson -Force
    Write-TeachObj 'lessons.json' $all
    return $id
}

function Remove-SnLesson {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Id)
    $all = Read-TeachObj 'lessons.json'; $all.PSObject.Properties.Remove($Id); Write-TeachObj 'lessons.json' $all
}

function Save-SnLessonProgress {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$LessonId, [int]$Step = 0, [string]$Status = 'in-progress', [int]$Score = -1, [int]$Total = -1)
    $p = Read-TeachObj 'lesson-progress.json'
    $old = $p.$LessonId
    $o = [pscustomobject]@{ step = $Step; status = $Status; score = $(if ($Score -ge 0) { $Score } else { [int](Get-Prop $old 'score') }); total = $(if ($Total -ge 0) { $Total } else { [int](Get-Prop $old 'total') }); at = (Get-Now) }
    $p | Add-Member -NotePropertyName $LessonId -NotePropertyValue $o -Force
    Write-TeachObj 'lesson-progress.json' $p
    return $o
}

function Add-SnFollowup {
    <# Your question / "explain it simpler" / "prepare a lesson" request, answered later by Claude. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Kind, [Parameter(Mandatory)][string]$Target, [string]$Concept, [string]$Text, [string]$Title)
    if ($script:FollowupKinds -notcontains $Kind) { throw "Kind must be one of: $($script:FollowupKinds -join ', ')" }
    if ($Kind -eq 'question' -and -not "$Text".Trim()) { throw 'Write your question first.' }
    $list = @(Read-LearnList 'followups.json')
    # don't stack identical open requests
    $dup = @($list | Where-Object { $_.kind -eq $Kind -and $_.target -eq $Target -and "$($_.concept)" -eq "$Concept" -and "$($_.text)" -eq "$Text" -and -not $_.answer })
    if ($dup.Count) { return $dup[0] }
    $f = [pscustomobject][ordered]@{ id = (New-LearnId 'F'); kind = $Kind; target = $Target; concept = "$Concept"; title = "$Title"; text = "$Text".Trim(); at = (Get-Now); answer = ''; example = ''; answeredAt = '' }
    Write-LearnList 'followups.json' (@($list) + $f)
    return $f
}

function Set-SnFollowupAnswer {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Id, [Parameter(Mandatory)][string]$Answer, [string]$Example)
    $list = @(Read-LearnList 'followups.json')
    $hit = $false
    foreach ($f in $list) { if ($f.id -eq $Id) { $f.answer = $Answer.Trim(); $f.example = "$Example".Trim(); $f.answeredAt = (Get-Now); $hit = $true } }
    if (-not $hit) { throw "Follow-up $Id not found." }
    Write-LearnList 'followups.json' $list
}

function Get-SnTeach {
    return [pscustomobject]@{
        lessons   = (Read-TeachObj 'lessons.json')
        concepts  = (Read-TeachObj 'concepts.json')
        progress  = (Read-TeachObj 'lesson-progress.json')
        followups = @(Read-LearnList 'followups.json')
    }
}

function Get-SnPendingFollowups {
    <# For Claude: what the user asked for in Stranote and is still waiting on. #>
    return @(Read-LearnList 'followups.json' | Where-Object { -not $_.answer })
}
