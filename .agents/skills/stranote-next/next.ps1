<#
  next.ps1 - READ-ONLY. Tells one agent which Stranote board task is its next one, by the same ladder as
  skill stranote-resume (Mode A step 2), so every model gets the same answer. It never writes anything:
  claim the task with board.ps1 (the command is printed for you).

  Run:  powershell -NoProfile -ExecutionPolicy Bypass -File D:\Projects\Stranote\.agents\skills\stranote-next\next.ps1 -Agent "Codex (gpt-6-luna)"
        add -Id S2      the task the user named
        add -Small      you run on a small model (Flash / mini / free plan): only docs/skill/pack-text reviews
                        (Cline and GitHub Copilot are always treated as small)

  Ladder: named > review by another agent kind > best fit > any open row > owner-decision memo > steps 6-7 of
  stranote-resume (find new work / health check), which need judgment and are not computed here.
  Exit code 0 always (nothing to refuse: it only reads).
#>
param(
    [Parameter(Mandatory = $true)][string]$Agent,
    [string]$Id,
    [switch]$Small,
    [string]$Path = 'D:\Projects\Stranote\STATE.md',
    [string]$Repo = 'D:\Projects\Stranote'
)
$ErrorActionPreference = 'Stop'
$utf8 = New-Object Text.UTF8Encoding $false
[Console]::OutputEncoding = $utf8

# Same parsing and overlap rules as board.ps1 (keep them in step)
function Get-Kind([string]$s) { $s = "$s".Trim(); $i = $s.IndexOf(' ('); if ($i -gt 0) { $s = $s.Substring(0, $i) }; return $s.Trim() }
function Split-Row([string]$line) {
    $p = $line.Split('|')
    if ($p.Count -ne 9) { return $null }
    return , @($p[1..7] | ForEach-Object { $_.Trim() })
}
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

# Agent kind -> branch prefix and the word that names it in the Fit column
$kind = Get-Kind $Agent
$map = @(
    @('Claude', 'claude', 'Claude'), @('Codex', 'codex', 'Codex'), @('Antigravity', 'antigravity', 'Antigravity'),
    @('Copilot', 'copilot', 'Copilot'), @('Cline', 'cline', 'Cline'), @('Kilo', 'kilo', 'Kilo'))
$prefix = ''; $fitWord = ''
foreach ($m in $map) { if ($kind -match [regex]::Escape($m[0])) { $prefix = $m[1]; $fitWord = $m[2] } }
if (-not $prefix) { $prefix = ($kind.ToLowerInvariant() -replace '[^a-z0-9]', ''); $fitWord = $kind }
if ($prefix -eq 'copilot' -or $prefix -eq 'cline') { $Small = $true }

$lines = [IO.File]::ReadAllLines($Path, [Text.Encoding]::UTF8)
$rows = @()
$inState = $false; $log = @(); $inLog = $false
foreach ($l in $lines) {
    if ($l -like '## CURRENT STATE*') { $inState = $true; continue }
    if (-not $inState) { continue }
    if ($l -like '### Log*') { $inLog = $true; continue }
    if ($inLog -and $l -like '- *') { $log += $l.Substring(2) }
    if ($l -match '^\| [A-Z]+[0-9]+ \|') { $c = Split-Row $l; if ($c) { $rows += , $c } }
}
function Get-Status($c) { return "$($c[3])".Trim().ToLowerInvariant() }
$claimed = @($rows | Where-Object { (Get-Status $_) -eq 'claimed' })
$busy = @($rows | Where-Object { @('claimed', 'reviewing') -contains (Get-Status $_) })

function Get-Overlap($c) {
    $mine = Get-Paths $c[6]
    foreach ($o in $claimed) { if ($o[0] -ne $c[0]) { $h = Test-Overlap $mine (Get-Paths $o[6]); if ($h) { return "$($o[0]) ($h)" } } }
    return $null
}
function Test-SmallReview([string]$branch) {
    # Small models review only branches that change docs, skill text or pack text (every file must match)
    $files = @(& 'C:\Program Files\Git\cmd\git.exe' -C $Repo diff --name-only "main...$branch" 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $files.Count) { return $false }
    return -not @($files | Where-Object { $_ -notmatch '(^(docs|specs)/.*\.md$)|(^\.agents/skills/.*\.md$)|(^packs/.*\.json$)|(^\.(github|clinerules|kilocode)/.*\.md$)|(^[^/]+\.md$)' }).Count
}

$pick = $null; $why = ''; $notes = @()

# 1. Named
if ($Id) {
    $n = @($rows | Where-Object { $_[0] -eq $Id })
    if (-not $n.Count) { $notes += "Row $Id is not on the board." }
    else {
        $st = Get-Status $n[0]
        if ($st -eq 'open' -or $st -eq 'review') {
            $ov = $null; if ($st -eq 'open') { $ov = Get-Overlap $n[0] }
            if ($ov) { $notes += "Named row $Id touches the same files as claimed row $ov." }
            else { $pick = $n[0]; $why = 'named' }
        }
        else { $notes += "Named row $Id is '$($n[0][3])', not free; going down the ladder." }
    }
}
# 2. A review by another agent kind
if (-not $pick) {
    foreach ($c in $rows) {
        if ((Get-Status $c) -ne 'review') { continue }
        $br = ("$($c[5])" -split '[ (]')[0].Trim()
        if ($br -notmatch '^[a-z0-9-]+/') { continue }
        if ($br.StartsWith("$prefix/")) { continue }
        if ($Small -and -not (Test-SmallReview $br)) { $notes += "Review $($c[0]) ($br) changes src/ or tests/: needs a strong model."; continue }
        $pick = $c; $why = "review of $br"; break
    }
}
# 3. Best fit, 4. any open row
if (-not $pick) {
    $second = $null
    foreach ($c in $rows) {
        if ((Get-Status $c) -ne 'open') { continue }
        $fit = "$($c[2])"
        if ($fit -match '^\s*owner\s*$') { continue }
        $ov = Get-Overlap $c
        if ($ov) { $notes += "Open row $($c[0]) waits: same files as claimed row $ov."; continue }
        if ($fit -match "(?i)\b$([regex]::Escape($fitWord))\b" -or $fit -match '(?i)\bany\b') { $pick = $c; $why = 'best fit'; break }
        if (-not $second) { $second = $c }
    }
    if (-not $pick -and $second) { $pick = $second; $why = 'any open row (not the best fit: say so)' }
}
# 5. Owner-decision memo
if (-not $pick) {
    foreach ($c in $rows) {
        # A memo noted in Status or in Claimed by (done or being written) means the row is covered
        if ((Get-Status $c) -like 'blocked: owner*' -and "$($c[3]) $($c[4])" -notmatch '(?i)memo') { $pick = $c; $why = 'owner-decision memo'; break }
    }
}

# Brief
$today = Get-Date -Format 'yyyy-MM-dd HH:mm'
Write-Output "## Stranote - next task for $kind ($today)"
if ($pick) {
    Write-Output "**Next:** $($pick[0]) - $($pick[1])"
    Write-Output "**Why:** $why  |  **Fit:** $($pick[2])  |  **Touches:** $($pick[6])"
    $B = "powershell -NoProfile -ExecutionPolicy Bypass -File $Repo\.agents\skills\stranote-resume\board.ps1 -Agent `"$Agent`""
    $st = Get-Status $pick
    if ($why -like 'review*') {
        $br = ("$($pick[5])" -split '[ (]')[0].Trim()
        Write-Output "**Claim:** $B -Id $($pick[0]) -Expect review -Status reviewing -ClaimedBy `"$Agent <yyyy-MM-dd HH:mm> - reviewing $br`""
    }
    elseif ($why -eq 'owner-decision memo') {
        Write-Output "**Claim:** $B -Id $($pick[0]) -Expect `"$($pick[3])`" -ClaimedBy `"$Agent <yyyy-MM-dd HH:mm> - writing memo`" -Branch $prefix/$($pick[0])-memo"
    }
    else {
        $br = "$($pick[5])"; if (-not $br) { $br = "$prefix/$($pick[0])" }
        Write-Output "**Claim:** $B -Id $($pick[0]) -Expect $st -Status claimed -ClaimedBy `"$Agent <yyyy-MM-dd HH:mm>`" -Branch $br"
    }
}
else {
    Write-Output '**Next:** nothing on the board for you. Do steps 6-7 of skill stranote-resume (find new work, else health check).'
}
$w = @($busy | ForEach-Object { "$($_[0]) ($(("$($_[4])" -split ' - ')[0]))" })
if ($w.Count) { Write-Output "**Working now:** $($w -join '; ')" } else { Write-Output '**Working now:** nobody' }
$ob = @($rows | Where-Object { (Get-Status $_) -like 'blocked: owner*' } | ForEach-Object { $_[0] })
if ($ob.Count) { Write-Output "**Blocked on owner:** $($ob -join ', ')" }
$ap = @($rows | Where-Object { (Get-Status $_) -eq 'approved' } | ForEach-Object { $_[0] })
if ($ap.Count) { Write-Output "**Ready to merge (owner: /stranote_resume merge):** $($ap -join ', ')" }
if ($log.Count) { Write-Output "**Last done:** $($log[0])" }
foreach ($n in $notes) { Write-Output "- $n" }
exit 0
