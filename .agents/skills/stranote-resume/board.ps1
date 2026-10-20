<#
  board.ps1 - the ONLY way any agent changes the Stranote task board (STATE.md).
  It takes a lock, re-reads the file, refuses stale or foreign changes, edits only the lines asked for, and writes
  atomically (temp file + replace). Every previous version is kept in %TEMP%\stranote-board\.

  Run:  powershell -NoProfile -ExecutionPolicy Bypass -File D:\Projects\Stranote\.agents\skills\stranote-resume\board.ps1 <args>

  Show the board:       -Agent "Codex (gpt-6-luna)" -Show
  Claim an open row:    -Agent "..." -Id U3 -Expect open -Status claimed -ClaimedBy "Codex (gpt-6-luna) 2026-10-20 18:00" -Branch codex/U3
  Start a review:       -Agent "..." -Id E2 -Expect review -Status reviewing -ClaimedBy "Codex (gpt-6-luna) 2026-10-20 18:00 - reviewing copilot/E2"
  Finish your row:      -Agent "..." -Id U3 -Expect claimed -Status review -ClaimedBy "Codex (gpt-6-luna) 2026-10-20 18:40 - done abc1234" -Log "U3 ... (codex/U3 abc1234, tests 113/113)"
  New row:              -Agent "..." -NewRow -Id U4 -Task "..." -Fit "any" -Status open -Touches "src/x.ps1"
  Shared line:          -Agent "..." -Field Tests -Value "113 pass, 0 fail on main (Codex, 2026-10-20)"
  Owner's order:        add -OwnerSaid "<the owner's words>" (lets you change a row you do not hold; logged)
  Merge (Mode C only):  add -Merge (approved -> done, or approved -> open with fixes)
  Archive done rows:    -Agent "..." -Archive          (moves every done row to STATE_HISTORY.md; anyone, any time)
  Fixed text:           -Agent "..." -ReplaceText "<exact old text>" -With "<new text>"  (never rows or log lines)

  Exit code 0 = written. Exit code 1 = refused: nothing was written; read the message, re-read the board, decide again.
#>
param(
    [Parameter(Mandatory = $true)][string]$Agent,
    [string]$Id,
    [string]$Expect,
    [string]$Status,
    [string]$ClaimedBy,
    [string]$Branch,
    [string]$Task,
    [string]$Fit,
    [string]$Touches,
    [switch]$NewRow,
    [string]$Log,
    [string]$Field,
    [string]$Value,
    [string]$OwnerSaid,
    [switch]$Merge,
    [switch]$Show,
    [switch]$Archive,
    [string]$ReplaceText,
    [string]$With,
    [string]$Path = 'D:\Projects\Stranote\STATE.md'
)
$ErrorActionPreference = 'Stop'
$utf8 = New-Object Text.UTF8Encoding $false
[Console]::OutputEncoding = $utf8

function Stop-Board([string]$msg) { Write-Output "REFUSED: $msg"; Write-Output 'Nothing was written. Re-read the board and decide again.'; exit 1 }
function Get-Kind([string]$s) { $s = "$s".Trim(); $i = $s.IndexOf(' ('); if ($i -gt 0) { $s = $s.Substring(0, $i) }; return $s.Trim() }
function Split-Row([string]$line) {
    $p = $line.Split('|')
    if ($p.Count -ne 9) { return $null }
    return , @($p[1..7] | ForEach-Object { $_.Trim() })
}
function Test-Holder([string]$cell, [string]$k) { return "$cell".Trim().StartsWith($k, [StringComparison]::OrdinalIgnoreCase) }
function Join-Row($c) { return '| ' + ($c -join ' | ') + ' |' }
function Get-Paths([string]$t) {
    $out = @()
    foreach ($part in ("$t" -replace '\([^)]*\)', '' -replace '(?i)\bhome:', '').Split(',;')) {
        $w = $part.Trim().Split(' ')[0].Trim('`').Replace('\', '/').TrimEnd('/').ToLowerInvariant()
        if (-not $w -or $w -eq 'home' -or $w -eq 'state.md') { continue }
        $star = $w.IndexOf('*'); if ($star -ge 0) { $w = $w.Substring(0, $star).TrimEnd('/') }
        if ($w) { $out += $w }
    }
    return , $out
}
function Test-Overlap($a, $b) {
    foreach ($x in $a) { foreach ($y in $b) {
        if ($x -eq $y -or $x.StartsWith($y + '/') -or $y.StartsWith($x + '/')) { return "$x ~ $y" } } }
    return $null
}

$kind = Get-Kind $Agent
if (-not $kind) { Stop-Board '-Agent is empty. Use your agent and model, e.g. "Codex (gpt-6-luna)".' }
foreach ($v in @($Id, $Status, $ClaimedBy, $Branch, $Task, $Fit, $Touches, $Log, $Value, $OwnerSaid)) {
    if ("$v" -match '[|\r\n]') { Stop-Board 'Values may not contain "|" or line breaks.' }
}
if (-not (Test-Path -LiteralPath $Path)) { Stop-Board "board not found: $Path" }

$dir = Split-Path -Parent $Path
$lockPath = Join-Path $dir '.board.lock'
$lastPath = Join-Path $dir '.board.last'
$bakDir = Join-Path $env:TEMP 'stranote-board'

# ---- lock (one writer at a time; a lock older than 60 s is stale) ----
$lock = $null; $deadline = (Get-Date).AddSeconds(30)
while (-not $lock) {
    try { $lock = New-Object IO.FileStream($lockPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None) }
    catch {
        try { if (((Get-Date) - (Get-Item -LiteralPath $lockPath).LastWriteTime).TotalSeconds -gt 60) { Remove-Item -LiteralPath $lockPath -Force } } catch {}
        if ((Get-Date) -gt $deadline) { Stop-Board "the board is locked by another agent (.board.lock) for more than 30 s." }
        Start-Sleep -Milliseconds 200
    }
}
try {
    $info = $utf8.GetBytes("$Agent pid $PID $((Get-Date).ToString('s'))"); $lock.Write($info, 0, $info.Length); $lock.Flush()

    $text = [IO.File]::ReadAllText($Path, $utf8)
    $lines = New-Object Collections.Generic.List[string]
    foreach ($l in ($text -replace "`r`n", "`n").TrimEnd("`n").Split("`n")) { $lines.Add($l) }

    # ---- edits made outside board.ps1 since the last board.ps1 write ----
    $warn = @()
    if (Test-Path -LiteralPath $lastPath) {
        $last = [IO.File]::ReadAllText($lastPath, $utf8)
        if ($last -ne $text) {
            $old = @(($last -replace "`r`n", "`n").Split("`n")); $new = @($lines)
            $gone = @($old | Where-Object { $new -notcontains $_ }); $added = @($new | Where-Object { $old -notcontains $_ })
            $warn += 'WARNING: STATE.md was changed outside board.ps1 since its last write. Check that nothing of another agent was lost:'
            $gone | ForEach-Object { $warn += "  - removed: $_" }
            $added | ForEach-Object { $warn += "  + added:   $_" }
        }
    }

    # ---- parse the table ----
    $head = -1; for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i].StartsWith('| ID | Task |')) { $head = $i; break } }
    if ($head -lt 0) { Stop-Board 'board table header "| ID | Task |" not found.' }
    $rows = @{}; $end = $head + 1
    for ($i = $head + 2; $i -lt $lines.Count -and $lines[$i].StartsWith('|'); $i++) {
        $c = Split-Row $lines[$i]
        if (-not $c) { Stop-Board "board row on line $($i + 1) is damaged (it needs exactly 7 cells). Ask the owner." }
        if ($rows.ContainsKey($c[0])) { Stop-Board "row id $($c[0]) appears twice. Ask the owner." }
        $rows[$c[0]] = $i; $end = $i
    }

    if ($Show) {
        $warn | ForEach-Object { Write-Output $_ }
        for ($i = $head; $i -le $end; $i++) { Write-Output $lines[$i] }
        exit 0
    }

    $did = @()
    $ownerNote = ''; if ($OwnerSaid) { $ownerNote = " (owner said: `"$OwnerSaid`")" }

    # ---- row change ----
    if ($Id) {
        if ($ClaimedBy -and -not $Merge -and -not $OwnerSaid -and -not (Test-Holder $ClaimedBy $kind)) {
            Stop-Board "-ClaimedBy must start with your own agent name ('$kind ...')."
        }
        $claimed = @($rows.Keys | Where-Object { $_ -ne $Id } | ForEach-Object { , (Split-Row $lines[$rows[$_]]) } | Where-Object { $_[3] -eq 'claimed' })
        if ($NewRow) {
            if ($rows.ContainsKey($Id)) { Stop-Board "row $Id already exists. Pick the next free id." }
            if (-not $Task -or -not $Status) { Stop-Board 'a new row needs -Task and -Status.' }
            if ($Status -eq 'claimed' -and -not (Test-Holder $ClaimedBy $kind)) { Stop-Board 'claiming a new row needs -ClaimedBy with your agent name.' }
            $c = @($Id, $Task, "$Fit", $Status, "$ClaimedBy", "$Branch", "$Touches")
            $lines.Insert($end + 1, (Join-Row $c)); $did += "new row $Id ($Status)"
        } else {
            if (-not $rows.ContainsKey($Id)) { Stop-Board "row $Id does not exist (use -NewRow to add it)." }
            if (-not $PSBoundParameters.ContainsKey('Expect')) { Stop-Board "-Expect '<status you read>' is required to change row $Id." }
            $c = Split-Row $lines[$rows[$Id]]
            $cur = $c[3]; $holder = Get-Kind $c[4]; $isMine = Test-Holder $c[4] $kind
            if ($cur -ne $Expect) { Stop-Board "row $Id is now '$cur', not '$Expect': someone changed it after you read it." }
            $to = $cur; if ($Status) { $to = $Status }
            $ok = $false; $why = ''
            if ($OwnerSaid) { $ok = $true }
            elseif ($Merge) { $ok = ($cur -eq 'approved'); $why = '-Merge only works on approved rows' }
            elseif ($cur -eq 'open') { $ok = ($to -eq 'claimed' -or $to -like 'blocked*'); $why = 'an open row can only be claimed' }
            elseif ($cur -eq 'review') {
                $ok = ($to -eq 'reviewing' -and -not $isMine)
                $why = 'a row in review can only be taken as reviewing, by an agent other than its author'
            }
            elseif ($cur -like 'blocked: owner*' -and -not $c[4]) { $ok = ($to -like 'blocked: owner*'); $why = 'only the owner unblocks a blocked: owner row (memo: keep blocked: owner)' }
            elseif ($cur -eq 'done' -or $cur -eq 'approved') { $why = "row $Id is $cur; only -Merge or -OwnerSaid may change it" }
            elseif ($cur -match '^blocked: ([A-Z]\d+(, ?[A-Z]\d+)*)$' -and -not $c[4]) {
                # blocked by other rows: free once every blocker is done or approved
                $open = @($Matches[1].Split(',') | ForEach-Object { $_.Trim() } | Where-Object {
                    -not $rows.ContainsKey($_) -or @('done', 'approved') -notcontains (Split-Row $lines[$rows[$_]])[3] })
                $ok = (-not $open.Count -and ($to -eq 'open' -or $to -eq 'claimed'))
                $why = "row $Id waits for $($open -join ', ') (must be done or approved first)"
            }
            elseif ($cur -like 'blocked*' -and -not $c[4]) { $why = "row $Id is $cur; only the owner may open it (-OwnerSaid)" }
            else { $ok = $isMine; $why = "row $Id is held by '$holder'; only the holder may change it" }
            if (-not $ok) { Stop-Board $why }
            if ($to -eq 'claimed' -and $cur -ne 'claimed' -and -not $ClaimedBy) { Stop-Board 'a claim needs -ClaimedBy "<your agent + model> <yyyy-MM-dd HH:mm>".' }
            if ($Status) { $c[3] = $Status }
            if ($PSBoundParameters.ContainsKey('ClaimedBy')) { $c[4] = $ClaimedBy }
            if ($PSBoundParameters.ContainsKey('Branch')) { $c[5] = $Branch }
            if ($PSBoundParameters.ContainsKey('Task')) { $c[1] = $Task }
            if ($PSBoundParameters.ContainsKey('Fit')) { $c[2] = $Fit }
            if ($PSBoundParameters.ContainsKey('Touches')) { $c[6] = $Touches }
            $lines[$rows[$Id]] = Join-Row $c; $did += "row $Id $cur -> $($c[3])"
        }
        if ($c[3] -eq 'claimed' -and ($NewRow -or $cur -ne 'claimed') -and -not $OwnerSaid) {
            $mine = Get-Paths $c[6]
            foreach ($o in $claimed) {
                $hit = Test-Overlap $mine (Get-Paths $o[6])
                if ($hit) { Stop-Board "row $Id touches the same files as claimed row $($o[0]) ($hit). Wait until it is done, or add your row as 'blocked: $($o[0])'." }
            }
        }
    }

    # ---- shared one-paragraph fields ----
    if ($Field) {
        if (-not $Value) { Stop-Board '-Field needs -Value.' }
        $fi = -1; for ($i = 0; $i -lt $head; $i++) { if ($lines[$i].StartsWith("**$Field")) { $fi = $i; break } }
        if ($fi -lt 0) { Stop-Board "field **$Field** not found above the board." }
        $label = $lines[$fi].Substring(0, $lines[$fi].IndexOf('**', 2) + 2)
        $j = $fi + 1; while ($j -lt $head -and $lines[$j] -and -not $lines[$j].StartsWith('**') -and -not $lines[$j].StartsWith('#')) { $lines.RemoveAt($j); $head--; $end-- }
        $lines[$fi] = "$label $Value"; $did += "field $Field"
    }

    # ---- log (newest first, keep 8) ----
    if ($OwnerSaid -and -not $Log) { $Log = "$Id changed on the owner's order" }
    if ($Log) {
        $li = -1; for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i].StartsWith('### Log')) { $li = $i; break } }
        if ($li -lt 0) { Stop-Board '"### Log" heading not found.' }
        $lines.Insert($li + 1, "- $((Get-Date).ToString('yyyy-MM-dd')) ${kind}: $Log$ownerNote")
        $n = 0; $i = $li + 1
        while ($i -lt $lines.Count -and $lines[$i].StartsWith('- ')) { $n++; if ($n -gt 5) { $lines.RemoveAt($i) } else { $i++ } }
        $did += 'log line'
    }
    # ---- fixed text (headings, intro, legend; never board rows or log lines) ----
    if ($ReplaceText) {
        if ("$With" -match '[\r\n]') { Stop-Board '-With may not contain line breaks.' }
        $hits = @(); for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i].Contains($ReplaceText)) { $hits += $i } }
        if ($hits.Count -ne 1) { Stop-Board "-ReplaceText must match exactly one line (found $($hits.Count))." }
        $h = $hits[0]
        if ($lines[$h].StartsWith('|') -or $lines[$h].StartsWith('- ') -or $lines[$h].StartsWith('<!-- Last updated:')) {
            Stop-Board '-ReplaceText may not change board rows, log lines or the Last updated line.'
        }
        $lines[$h] = $lines[$h].Replace($ReplaceText, "$With"); $did += "text on line $($h + 1)"
    }

    # ---- archive: done rows move to STATE_HISTORY.md ----
    $histPath = Join-Path $dir 'STATE_HISTORY.md'; $histText = $null
    if ($Archive) {
        $moved = @()
        for ($i = $lines.Count - 1; $i -ge 0; $i--) {
            if ($lines[$i] -match '^\| [A-Z]+\d+ \|') { $c = Split-Row $lines[$i]; if ($c -and $c[3] -eq 'done') { $moved = @($lines[$i]) + $moved; $lines.RemoveAt($i) } }
        }
        if ($moved.Count) {
            $histText = ''
            if (Test-Path -LiteralPath $histPath) { $histText = [IO.File]::ReadAllText($histPath, $utf8).TrimEnd("`n") + "`n" }
            else { $histText = "# Stranote - finished board rows`n`nMoved here from ``STATE.md`` by ``board.ps1 -Archive`` (newest batch last). Details: git log and ``specs/*/tasks.md``.`n`n| ID | Task | Fit | Status | Claimed by | Branch | Touches |`n|---|---|---|---|---|---|---|`n" }
            $histText += ($moved -join "`n") + "`n"
            $did += "archived $($moved.Count) done rows"
        }
    }

    if (-not $did.Count) { Stop-Board 'nothing to change (give -Id, -Field, -Log, -Archive or -ReplaceText).' }

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].StartsWith('<!-- Last updated:')) { $lines[$i] = "<!-- Last updated: $((Get-Date).ToString('yyyy-MM-dd HH:mm')) by $Agent - $($did -join ', ') -->"; break }
    }

    # ---- backup, atomic write, remember what we wrote ----
    if (-not (Test-Path $bakDir)) { New-Item -ItemType Directory -Path $bakDir -Force | Out-Null }
    [IO.File]::WriteAllText((Join-Path $bakDir ("STATE-" + (Get-Date).ToString('yyyyMMdd-HHmmss-fff') + '.md')), $text, $utf8)
    Get-ChildItem $bakDir -Filter 'STATE-*.md' | Sort-Object Name -Descending | Select-Object -Skip 50 | Remove-Item -Force
    if ($null -ne $histText) {
        # history first: a failure after this leaves a row in both files, never in neither
        [IO.File]::WriteAllText("$histPath.tmp", $histText, $utf8)
        if (Test-Path -LiteralPath $histPath) { [IO.File]::Replace("$histPath.tmp", $histPath, [NullString]::Value) } else { [IO.File]::Move("$histPath.tmp", $histPath) }
    }
    $newText = ($lines -join "`n") + "`n"
    $tmp = "$Path.tmp"
    [IO.File]::WriteAllText($tmp, $newText, $utf8)
    [IO.File]::Replace($tmp, $Path, [NullString]::Value)
    [IO.File]::WriteAllText($lastPath, $newText, $utf8)

    $warn | ForEach-Object { Write-Output $_ }
    Write-Output "OK: $($did -join ', ')"
    if ($Id) { $k = -1; for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i].StartsWith("| $Id |")) { $k = $i } }; if ($k -ge 0) { Write-Output $lines[$k] } }
}
finally {
    if (Test-Path -LiteralPath "$Path.tmp") { Remove-Item -LiteralPath "$Path.tmp" -Force -ErrorAction SilentlyContinue }
    if ($lock) { $lock.Dispose(); Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue }
}
