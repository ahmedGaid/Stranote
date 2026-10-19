# Daily review ("مراجعة الصبح"): short memory + long memory.
# Dot-sourced by StranoteCore.ps1 after StranoteLearn.ps1 and StranoteTeach.ps1.
#
#   short    - learned recently (box 1-2) and due: fixes it in memory while it is fresh
#   long     - older (box 3-5) and due
#   surprise - not due yet, picked at random from things you learned a while ago
#              (the longer since you last saw it, the likelier). Checks you can still recall it.
#              A right answer keeps its schedule; a wrong one brings it back tomorrow.
# Data: 04_Knowledge\Stranote\review-log.json  { days: { "yyyy-MM-dd": { n, right, wrong, at } } }

function Get-ReviewLog {
    $p = Join-Path (Get-LearnDir) 'review-log.json'
    if (Test-Path $p) { try { $o = Get-Content $p -Raw -Encoding UTF8 | ConvertFrom-Json; if ($o -and $o.days) { return $o } } catch { } }
    return [pscustomobject]@{ days = [pscustomobject]@{} }
}

function Get-SnReviewStreak {
    <# Days in a row with a finished review, ending today (or yesterday if today is not done yet).
       Weekend days (settings career.weekend) never break the streak. #>
    param($Log, [datetime]$Today = (Get-Date).Date, $Weekend)
    if (-not $Log) { $Log = Get-ReviewLog }
    if ($null -eq $Weekend) { try { $Weekend = @((Get-SnSettings).career.weekend) } catch { $Weekend = @() } }
    $done = @{}; foreach ($p in $Log.days.PSObject.Properties) { $done[$p.Name] = $true }
    $d = $Today; $n = 0
    if (-not $done[$d.ToString('yyyy-MM-dd')]) { $d = $d.AddDays(-1) }
    for ($i = 0; $i -lt 3650; $i++) {
        $k = $d.ToString('yyyy-MM-dd')
        if ($done[$k]) { $n++ }
        elseif (@($Weekend) -notcontains $d.DayOfWeek.ToString().Substring(0, 3)) { break }
        $d = $d.AddDays(-1)
    }
    return $n
}

function Get-SnDailyReview {
    [CmdletBinding()]
    param([int]$Size = 10, [int]$Surprise = 3, [int]$Seed = -1, [string]$Today = (Get-Today))
    $rnd = if ($Seed -ge 0) { New-Object Random $Seed } else { New-Object Random }
    $teach = Get-SnTeach
    $qs = @(Read-LearnList 'questions.json' | Where-Object { $_ -and (Test-SnQuestionReady -Question $_ -Statuses $teach.concepts) })
    $todayD = [datetime]::ParseExact($Today, 'yyyy-MM-dd', $null)
    $age = { param($q) $l = "$($q.lastAt)"; if ($l.Length -ge 10) { ($todayD - [datetime]::ParseExact($l.Substring(0, 10), 'yyyy-MM-dd', $null)).TotalDays } else { 0 } }

    $due = @($qs | Where-Object { -not "$($_.due)" -or "$($_.due)" -le $Today } | Sort-Object @{ e = { [int]$_.box } }, @{ e = { "$($_.due)" } })
    # surprise candidates: practiced before, not due, not seen in the last 3 days
    $cand = @($qs | Where-Object { "$($_.due)" -gt $Today -and [int]$_.seen -gt 0 -and (& $age $_) -ge 3 })
    $nSur = [Math]::Min($Surprise, $cand.Count)
    if ($due.Count -lt ($Size - $nSur)) { $nSur = [Math]::Min($cand.Count, $Size - $due.Count) }   # quiet day: more old material
    $nDue = [Math]::Min($due.Count, $Size - $nSur)

    $items = New-Object System.Collections.ArrayList
    foreach ($q in ($due | Select-Object -First $nDue)) { [void]$items.Add([pscustomobject]@{ id = $q.id; reason = $(if ([int]$q.box -le 2) { 'short' } else { 'long' }) }) }
    # weighted pick without replacement: weight = days since last seen + 7 x box (older and stronger = better test of long memory)
    $pool = New-Object System.Collections.ArrayList; $cand | ForEach-Object { [void]$pool.Add($_) }
    for ($i = 0; $i -lt $nSur; $i++) {
        $w = @($pool | ForEach-Object { 1 + (& $age $_) + 7 * [int]$_.box }); $sum = ($w | Measure-Object -Sum).Sum
        $r = $rnd.NextDouble() * $sum; $j = 0
        while ($j -lt $w.Count - 1 -and $r -ge $w[$j]) { $r -= $w[$j]; $j++ }
        [void]$items.Add([pscustomobject]@{ id = $pool[$j].id; reason = 'surprise' }); $pool.RemoveAt($j)
    }
    # interleave: mixing topics and old/new helps recall more than blocks of one kind
    $arr = @($items)
    for ($i = $arr.Count - 1; $i -gt 0; $i--) { $j = $rnd.Next($i + 1); $t = $arr[$i]; $arr[$i] = $arr[$j]; $arr[$j] = $t }

    $log = Get-ReviewLog
    $seenQs = @($qs | Where-Object { [int]$_.seen -gt 0 })
    # today's new lesson from the first-week plan (onboarding): the first open item due today or earlier
    $lesson = $null
    $plan = Get-SnPlan
    for ($i = 0; $i -lt @($plan.items).Count; $i++) {
        $it = $plan.items[$i]
        if ($it.status -eq 'todo' -and "$($it.day)" -le $Today) { $lesson = [pscustomobject]@{ index = $i; areaId = $it.areaId; conceptId = $it.conceptId; title = $it.title; minutes = $it.minutes; day = $it.day }; break }
    }
    return [pscustomobject]@{
        date = $Today; doneToday = [bool]($log.days.PSObject.Properties.Name -contains $Today)
        lesson = $lesson
        today = $log.days.$Today
        streak = (Get-SnReviewStreak -Log $log -Today $todayD)
        items = @($arr); dueLeft = [Math]::Max(0, $due.Count - $nDue)
        memory = [pscustomobject]@{
            fresh  = @($seenQs | Where-Object { [int]$_.box -le 2 }).Count   # short memory
            growing = @($seenQs | Where-Object { [int]$_.box -eq 3 }).Count
            strong = @($seenQs | Where-Object { [int]$_.box -ge 4 }).Count   # long memory
            locked = @(Read-LearnList 'questions.json').Count - $qs.Count
        }
    }
}

function Save-SnReviewDay {
    [CmdletBinding()]
    param([int]$Right, [int]$Wrong, [string]$Day = (Get-Today))
    $log = Get-ReviewLog
    $old = $log.days.$Day
    $n = [pscustomobject]@{ n = $Right + $Wrong + [int]$old.n; right = $Right + [int]$old.right; wrong = $Wrong + [int]$old.wrong; at = (Get-Now) }
    $log.days | Add-Member -NotePropertyName $Day -NotePropertyValue $n -Force
    Write-Utf8 (Join-Path (Get-LearnDir) 'review-log.json') ($log | ConvertTo-Json -Depth 5)
    return [pscustomobject]@{ day = $n; streak = (Get-SnReviewStreak -Log $log -Today ([datetime]::ParseExact($Day, 'yyyy-MM-dd', $null))) }
}
