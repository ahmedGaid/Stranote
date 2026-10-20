# Stranote core - task intake, folder scaffolding and progress tracking. Loaded by Stranote.psm1 (and the old-name
# wrappers Ops.psm1 / EbsTasks.psm1).
# Usage: double-click D:\Work\ebs.cmd or dashboard.cmd, or Import-Module this file and call the functions.
# Settings = engine defaults (settings.default.json) <- career pack (packs\*.json) <- your overrides (StranotePacks.ps1).

# Windows PowerShell 5.1 adds an ETS 'Count' member to System.Array, so ConvertTo-Json writes an array that went
# through a function return as {"value":[...],"Count":n}. Removing that type data is the standard fix; arrays keep
# their normal .Count.
Remove-TypeData System.Array -ErrorAction SilentlyContinue

# Env vars were OPS_* before the Stranote rename: still honour them when the STRANOTE_* one is not set.
foreach ($n in 'CONFIG', 'ROOT', 'LEARN_DIR', 'PACKS_DIR', 'NO_SCHEDULE') {
    $old = [Environment]::GetEnvironmentVariable("OPS_$n")
    if ($old -and -not [Environment]::GetEnvironmentVariable("STRANOTE_$n")) { Set-Item "env:STRANOTE_$n" $old }
}

$script:ToolDir     = $PSScriptRoot
$script:ConfigPath   = Join-Path $PSScriptRoot 'config.json'
$script:SettingsPath = Join-Path $PSScriptRoot 'settings.json'
$script:DefaultsPath = Join-Path $PSScriptRoot 'settings.default.json'
$script:BackupPath   = Join-Path $PSScriptRoot 'settings.backup.json'
$script:Utf8         = New-Object System.Text.UTF8Encoding $false
$script:RequiredWorkFolders = @('01_Tickets', '99_Archive')

# ---------------------------------------------------------------------------
# Config (root + auto-id counter) and settings (everything user-editable)
# ---------------------------------------------------------------------------

function Get-SnConfigPath {
    # STRANOTE_CONFIG points tests and extra installs at another config.json (and so another work root)
    if ($env:STRANOTE_CONFIG) { return $env:STRANOTE_CONFIG }
    return $script:ConfigPath
}

function Get-SnConfig {
    $p = Get-SnConfigPath
    if (-not (Test-Path $p)) {
        # first run of a fresh install: work root = STRANOTE_ROOT or D:\Work
        $root = if ($env:STRANOTE_ROOT) { $env:STRANOTE_ROOT } else { 'D:\Work' }
        [IO.File]::WriteAllText($p, ([pscustomobject][ordered]@{ root = $root; prefix = ''; author = ''; nextAutoId = 1 } | ConvertTo-Json), $script:Utf8)
    }
    return [IO.File]::ReadAllText($p) | ConvertFrom-Json
}

function Save-SnConfig($cfg) {
    [IO.File]::WriteAllText((Get-SnConfigPath), ($cfg | ConvertTo-Json -Depth 5), $script:Utf8)
}

function Get-SnSettings {
    # With a profile: engine defaults <- career pack <- your overrides (StranotePacks.ps1).
    if (Get-SnProfile) { return Get-SnEffectiveSettings }
    # Before migration / onboarding: the old single settings.json, or plain engine defaults.
    if (-not (Test-Path $script:SettingsPath)) { return (Get-SnEngineDefaults) }
    $s = [IO.File]::ReadAllText($script:SettingsPath) | ConvertFrom-Json
    # Fill in settings added in newer versions of the tool
    $d = [IO.File]::ReadAllText($script:DefaultsPath) | ConvertFrom-Json
    foreach ($p in $d.PSObject.Properties) {
        if (-not ($s.PSObject.Properties.Name -contains $p.Name)) { $s | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value }
    }
    return $s
}

function Test-RelPath([string]$Path, [string]$What) {
    if ([string]::IsNullOrWhiteSpace($Path)) { throw "$What has an empty folder name." }
    if ($Path -match '(^[\\/])|(:)|(\.\.)|[*?"<>|]') { throw "$What '$Path' is not a valid relative folder name." }
}

function Assert-SnSettings($s) {
    if ("$($s.prefix)" -and -not ($s.prefix -match '^[A-Za-z][A-Za-z0-9_]{0,9}$')) { throw 'Prefix must be empty or letters/digits/underscore, start with a letter, max 10 chars.' }
    foreach ($n in 'modules', 'priorities') {
        $list = @($s.$n | Where-Object { "$_".Trim() })
        if (-not $list.Count) { throw "List '$n' needs at least one value." }
        if (@($list | Select-Object -Unique).Count -ne $list.Count) { throw "List '$n' has duplicate values." }
    }
    if (@($s.priorities) -notcontains $s.defaultPriority) { throw "Default priority '$($s.defaultPriority)' is not in the priority list." }
    $ph = @($s.phases | ForEach-Object { $_.name })
    if ($ph -notcontains 'Done') { throw "Phases must include 'Done' (used when closing a task)." }
    if ($ph.Count -lt 2) { throw 'Need at least one phase besides Done.' }
    if (@($ph | Select-Object -Unique).Count -ne $ph.Count) { throw 'Phase names must be unique.' }
    foreach ($p in $s.phases) {
        if (-not "$($p.name)".Trim()) { throw 'A phase has an empty name.' }
        if ($null -ne $p.percent -and ([int]$p.percent -lt 0 -or [int]$p.percent -gt 100)) { throw "Phase '$($p.name)' percent must be 0-100 or empty." }
    }
    $tn = @($s.types | ForEach-Object { $_.name })
    if (-not $tn.Count) { throw 'Need at least one task type.' }
    if (@($tn | Select-Object -Unique).Count -ne $tn.Count) { throw 'Task type names must be unique.' }
    foreach ($t in $s.types) {
        if (-not "$($t.name)".Trim()) { throw 'A task type has an empty name.' }
        $qs = @(@($t.questions) | Where-Object { $_ })   # a type without questions is fine ($null would count as one key)
        $keys = @($qs | ForEach-Object { $_.k })
        foreach ($q in $qs) {
            if (-not ("$($q.k)" -match '^[A-Za-z][A-Za-z0-9_]*$')) { throw "Type '$($t.name)': question key '$($q.k)' must be letters/digits/underscore." }
            if (-not "$($q.q)".Trim()) { throw "Type '$($t.name)': question '$($q.k)' has no text." }
        }
        if (@($keys | Select-Object -Unique).Count -ne $keys.Count) { throw "Type '$($t.name)': question keys must be unique." }
    }
    if (-not ("$($s.ticketFolderName)" -match '\{id\}')) { throw 'Ticket folder name pattern must contain {id}.' }
    foreach ($f in $s.ticketFolders) { Test-RelPath $f 'Ticket subfolder' }
    foreach ($f in $s.workFolders) { Test-RelPath $f 'Work folder' }
    if ($s.appearance -and "$($s.appearance.accent)" -notmatch '^#[0-9A-Fa-f]{6}$') { throw 'Accent color must be a hex color like #C74634.' }
    if ($s.appearance -and $s.appearance.learnAccent -and "$($s.appearance.learnAccent)" -notmatch '^#[0-9A-Fa-f]{6}$') { throw 'Learning accent must be a hex color like #4F46E5.' }
    if ($s.career) {
        $current = 0
        foreach ($c in @($s.career.companies | Where-Object { $_ })) {
            if (-not "$($c.name)".Trim()) { throw 'A company has no name.' }
            $d = [datetime]::MinValue
            if (-not [datetime]::TryParseExact("$($c.start)", 'yyyy-MM-dd', $null, 'None', [ref]$d)) { throw "Company '$($c.name)': start date is required (yyyy-MM-dd)." }
            if ("$($c.end)") {
                $e = [datetime]::MinValue
                if (-not [datetime]::TryParseExact("$($c.end)", 'yyyy-MM-dd', $null, 'None', [ref]$e)) { throw "Company '$($c.name)': end date must be yyyy-MM-dd or empty." }
                if ($e -lt $d) { throw "Company '$($c.name)': end date is before start date." }
            } else { $current++ }
        }
    }
    foreach ($t in @($s.saveTargets)) {
        if (-not "$($t.name)".Trim()) { throw 'A save destination has no name.' }
        $rel = ("$($t.path)" -replace '^\{ticket\}[\\/]?', '') -replace '\{(id|module|type)\}', 'x'
        if ($rel) { Test-RelPath $rel "Save destination '$($t.name)'" }
    }
    foreach ($r in $script:RequiredWorkFolders) { if (@($s.workFolders) -notcontains $r) { throw "Work folders must keep '$r' (the tool stores tickets there)." } }
}

function Save-SnSettings {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Settings, [switch]$ApplyToActiveTickets)
    Assert-SnSettings $Settings
    if (Get-SnProfile) { Save-SnOverrides -Settings $Settings | Out-Null }   # only your changes, on top of the career pack
    else {
        if (Test-Path $script:SettingsPath) { Copy-Item $script:SettingsPath $script:BackupPath -Force }
        Write-Utf8 $script:SettingsPath ($Settings | ConvertTo-Json -Depth 10)
    }

    # Create any new folders. Never deletes or renames existing ones.
    $cfg = Get-SnConfig
    $created = @()
    foreach ($f in $Settings.workFolders) {
        $full = Join-Path $cfg.root $f
        if (-not (Test-Path $full)) { New-Item -ItemType Directory -Force -Path $full | Out-Null; $created += $f }
    }
    $ticketsUpdated = 0
    if ($ApplyToActiveTickets) {
        foreach ($t in Get-SnTaskList) {
            $added = $false
            foreach ($sub in $Settings.ticketFolders) {
                $full = Join-Path $t._path $sub
                if (-not (Test-Path $full)) { New-Item -ItemType Directory -Force -Path $full | Out-Null; $added = $true }
            }
            if ($added) { $ticketsUpdated++ }
        }
    }
    Update-SnDashboard | Out-Null
    return [pscustomobject]@{ createdFolders = $created; ticketsUpdated = $ticketsUpdated }
}

function Reset-SnSettings {
    [CmdletBinding()]
    param()
    $d = Get-SnBaseSettings (Get-SnActivePack)   # engine defaults + career pack
    $cur = Get-SnSettings
    $d.prefix = $cur.prefix
    $d.career = $cur.career   # your company history is personal data, never reset
    return Save-SnSettings -Settings $d
}

function Restore-SnSettingsBackup {
    [CmdletBinding()]
    param()
    if (Get-SnProfile) {
        $bp = Join-Path (Get-LearnDir) 'overrides.backup.json'
        if (-not (Test-Path $bp)) { throw 'No backup yet - backups are made each time settings are saved.' }
        $b = Merge-SnObject (Get-SnBaseSettings (Get-SnActivePack)) ([IO.File]::ReadAllText($bp) | ConvertFrom-Json)
        return Save-SnSettings -Settings $b
    }
    if (-not (Test-Path $script:BackupPath)) { throw 'No backup yet - backups are made each time settings are saved.' }
    $b = [IO.File]::ReadAllText($script:BackupPath) | ConvertFrom-Json
    return Save-SnSettings -Settings $b
}

function Get-CurrentCompany($s) {
    $c = @($s.career.companies | Where-Object { $_ -and -not "$($_.end)" } | Sort-Object { "$($_.start)" } -Descending)
    if ($c.Count) { return [string]$c[0].name }
    return ''
}

function Get-PhaseNames($s) { return @($s.phases | ForEach-Object { $_.name }) }

function Get-PhasePct($s) {
    $h = @{}
    foreach ($p in $s.phases) { if ($null -ne $p.percent -and "$($p.percent)" -ne '') { $h[$p.name] = [int]$p.percent } }
    return $h
}

function Get-TypeDef($s, [string]$Name) {
    $t = @($s.types | Where-Object { $_.name -ieq $Name })
    if ($t.Count) { return $t[0] }
    return $null
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Write-Utf8($Path, $Text) { [IO.File]::WriteAllText($Path, $Text, $script:Utf8) }

function Get-Now { (Get-Date).ToString('yyyy-MM-dd HH:mm') }

function ConvertTo-SnDate([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    $v = $Value.Trim()
    if ($v -match '^\+(\d+)$') { return (Get-Date).AddDays([int]$Matches[1]).ToString('yyyy-MM-dd') }
    $d = [datetime]::MinValue
    if ([datetime]::TryParseExact($v, 'yyyy-MM-dd', $null, 'None', [ref]$d)) { return $d.ToString('yyyy-MM-dd') }
    throw "Date '$Value' must be yyyy-MM-dd or +N (days from today)."
}

function Read-Text([string]$Prompt, [string]$Default = '', [switch]$Required) {
    while ($true) {
        $p = $Prompt
        if ($Default) { $p += " [$Default]" }
        $a = Read-Host $p
        if ([string]::IsNullOrWhiteSpace($a)) { $a = $Default }
        if ($Required -and [string]::IsNullOrWhiteSpace($a)) { Write-Host '  (required)' -ForegroundColor Yellow; continue }
        return $a
    }
}

function Read-Choice([string]$Prompt, [string[]]$Choices, [string]$Default = '') {
    Write-Host $Prompt -ForegroundColor Cyan
    $line = ''
    for ($i = 0; $i -lt $Choices.Count; $i++) { $line += ('  {0}) {1}' -f ($i + 1), $Choices[$i]) }
    Write-Host $line
    while ($true) {
        $p = '  Choose number or name'
        if ($Default) { $p += " [$Default]" }
        $a = Read-Host $p
        if ([string]::IsNullOrWhiteSpace($a)) { if ($Default) { return $Default } else { continue } }
        $n = 0
        if ([int]::TryParse($a, [ref]$n)) {
            if ($n -ge 1 -and $n -le $Choices.Count) { return $Choices[$n - 1] }
            continue
        }
        $m = @($Choices | Where-Object { $_ -ieq $a.Trim() })
        if ($m.Count) { return $m[0] }
        return $a.Trim()
    }
}

function Read-Date([string]$Prompt, [string]$Default = '') {
    while ($true) {
        $a = Read-Text $Prompt $Default
        try { return (ConvertTo-SnDate $a) } catch { Write-Host "  $($_.Exception.Message)" -ForegroundColor Yellow }
    }
}

function Get-SafeName([string]$Text, [int]$Max = 40, [switch]$KeepHyphen) {
    $pattern = if ($KeepHyphen) { '[^A-Za-z0-9-]+' } else { '[^A-Za-z0-9]+' }
    $s = ($Text -replace $pattern, '_').Trim('_')
    if ($s.Length -gt $Max) { $s = $s.Substring(0, $Max).TrimEnd('_') }
    return $s
}

function Get-ShortCode($s, [string]$Title, [string]$Module = '') {
    $stop = @($Module.ToUpper()) + @($s.stopWords | ForEach-Object { "$_".ToUpper() })
    $abbr = @{}
    if ($s.abbreviations) { foreach ($p in $s.abbreviations.PSObject.Properties) { $abbr[$p.Name.ToUpper()] = [string]$p.Value } }
    $words = @(($Title.ToUpper() -replace '[^A-Z0-9 ]', ' ') -split '\s+' | Where-Object { $_ -and ($stop -notcontains $_) })
    if (-not $words.Count) { return 'TASK' }
    $parts = @($words | ForEach-Object {
        if ($abbr.ContainsKey($_)) { $abbr[$_] } elseif ($_.Length -gt 5) { $_.Substring(0, 4) } else { $_ }
    } | Select-Object -Unique | Select-Object -First 3)
    return ($parts -join '_')
}

function Expand-Pattern([string]$Pattern, [hashtable]$Tokens) {
    $r = $Pattern
    foreach ($k in $Tokens.Keys) { $r = $r.Replace('{' + $k + '}', [string]$Tokens[$k]) }
    return $r
}

function Get-SnTaskList([switch]$IncludeArchive) {
    $cfg = Get-SnConfig
    $paths = @(Join-Path $cfg.root '01_Tickets')
    if ($IncludeArchive) { $paths += (Join-Path $cfg.root '99_Archive') }
    $list = @()
    foreach ($p in $paths) {
        if (-not (Test-Path $p)) { continue }
        foreach ($f in Get-ChildItem -Path $p -Recurse -Filter 'task.json' -File) {
            try {
                $t = [IO.File]::ReadAllText($f.FullName) | ConvertFrom-Json
                $t | Add-Member -NotePropertyName '_path' -NotePropertyValue $f.DirectoryName -Force
                $t | Add-Member -NotePropertyName '_archived' -NotePropertyValue ($p -like '*99_Archive') -Force
                $list += $t
            } catch { Write-Warning "Could not read $($f.FullName): $($_.Exception.Message)" }
        }
    }
    return $list
}

function Find-SnTask([string]$Id, [switch]$IncludeArchive) {
    $t = @(Get-SnTaskList -IncludeArchive:$IncludeArchive | Where-Object { $_.id -ieq $Id })
    if (-not $t.Count) { throw "Task '$Id' not found." }
    return $t[0]
}

function Save-SnTask($Task) {
    $clean = $Task | Select-Object -Property * -ExcludeProperty '_path', '_archived'
    Write-Utf8 (Join-Path $Task._path 'task.json') ($clean | ConvertTo-Json -Depth 8)
}

function Add-NotesLog($Task, [string]$Line) {
    $notes = Join-Path $Task._path '_NOTES.md'
    if (Test-Path $notes) { [IO.File]::AppendAllText($notes, "- $Line`r`n", $script:Utf8) }
}

# ---------------------------------------------------------------------------
# Public commands
# ---------------------------------------------------------------------------

function New-SnTask {
    [CmdletBinding()]
    param(
        [string]$Id, [string]$Title, [string]$Module, [string]$Type, [string]$Priority,
        [string]$Due, [string]$Requester, [string]$Description, [string]$ShortCode,
        [hashtable]$Details, [string[]]$ExtraQuestions, [switch]$NonInteractive
    )
    $cfg = Get-SnConfig
    $s = Get-SnSettings
    $typeNames = @($s.types | ForEach-Object { $_.name })
    $ask = -not $NonInteractive

    if ($ask) {
        Write-Host ''
        Write-Host '=== New task (Stranote) ===' -ForegroundColor Green
        Write-Host '(Press Enter to accept [defaults]. Leave Ticket ID blank to auto-number.)' -ForegroundColor DarkGray
        if (-not $Id)          { $Id = Read-Text 'Ticket ID (e.g. CR-1042, INC12345)' }
        if (-not $Title)       { $Title = Read-Text 'Short title' -Required }
        if (-not $Module)      { $Module = Read-Choice 'Module' @($s.modules) }
        if (-not $Type)        { $Type = Read-Choice 'Type' $typeNames }
        if (-not $Priority)    { $Priority = Read-Choice 'Priority' @($s.priorities) $s.defaultPriority }
        if (-not $Due)         { $Due = Read-Date 'Due date (yyyy-MM-dd or +N days, blank = none)' }
        if (-not $Requester)   { $Requester = Read-Text 'Requester / business owner' }
        if (-not $Description) { $Description = Read-Text 'Description (one or two sentences)' }
    }
    if (-not $Title) { throw 'Title is required.' }
    if (-not $Module) { $Module = @($s.modules)[-1] }
    $mm = @($s.modules | Where-Object { $_ -ieq $Module }); if ($mm.Count) { $Module = $mm[0] } else { $Module = $Module.ToUpper() }
    $typeDef = Get-TypeDef $s $Type
    if (-not $typeDef) { $typeDef = Get-TypeDef $s 'Other' }
    if (-not $typeDef) { $typeDef = @($s.types)[-1] }
    $Type = $typeDef.name
    if (-not $Priority) { $Priority = $s.defaultPriority }
    $Due = ConvertTo-SnDate $Due

    if (-not $Id) {
        $Id = '{0}{1:D4}' -f $s.autoIdPrefix, [int]$cfg.nextAutoId
        $cfg.nextAutoId = [int]$cfg.nextAutoId + 1
        Save-SnConfig $cfg
    }
    $Id = $Id.Trim().ToUpper()
    if (@(Get-SnTaskList -IncludeArchive | Where-Object { $_.id -ieq $Id }).Count) { throw "Task '$Id' already exists." }

    # Type-specific details
    $detailList = @()
    $qs = @($typeDef.questions | Where-Object { $_ -and $_.k })
    if ($ask -and $qs.Count) { Write-Host "--- $Type details ---" -ForegroundColor Green }
    foreach ($q in $qs) {
        $val = ''
        if ($Details -and $Details.ContainsKey($q.k)) { $val = [string]$Details[$q.k] }
        elseif ($ask) { $val = Read-Text $q.q ([string]$q.d) }
        if ($val) { $detailList += [pscustomobject]@{ q = $q.q; a = $val } }
    }
    if ($Details) {
        $known = @($qs | ForEach-Object { $_.k })
        foreach ($k in $Details.Keys) { if ($known -notcontains $k) { $detailList += [pscustomobject]@{ q = $k; a = [string]$Details[$k] } } }
    }

    $objPatterns = @($typeDef.objects | Where-Object { $_ })
    if (-not $ShortCode) {
        $ShortCode = Get-ShortCode $s $Title $Module
        if ($ask -and $objPatterns.Count) { $ShortCode = Read-Text 'Short code for object names' $ShortCode }
    }
    $ShortCode = (Get-SafeName $ShortCode 20).ToUpper()

    $questions = @()
    foreach ($q in (@($typeDef.openQuestions) + @($s.commonQuestions) + @($ExtraQuestions) | Where-Object { "$_".Trim() })) {
        $questions += [pscustomobject]@{ q = $q; answered = $false; answer = '' }
    }
    $checklist = @()
    foreach ($c in (@($typeDef.checklist) + @($s.baseChecklist) | Where-Object { "$_".Trim() })) { $checklist += [pscustomobject]@{ item = $c; done = $false } }

    $tok = @{ prefix = $s.prefix; prefixLower = $s.prefix.ToLower(); module = $Module; code = $ShortCode; base = "$($s.prefix)_$($Module)_$ShortCode"; id = $Id; type = $Type }
    $objects = @($objPatterns | ForEach-Object { Expand-Pattern $_ $tok })
    $branch = Expand-Pattern $s.branchPattern $tok

    $phases = Get-PhaseNames $s
    $firstPhase = $phases[0]
    $now = Get-Now
    $task = [pscustomobject][ordered]@{
        id = $Id; title = $Title; company = (Get-CurrentCompany $s); module = $Module; type = $Type; priority = $Priority
        due = $Due; requester = $Requester; description = $Description
        phase = $firstPhase; percent = 0; blocker = ''
        created = $now; updated = $now; closed = ''
        branch = $branch; shortCode = $ShortCode
        details = $detailList; objects = $objects; questions = $questions; checklist = $checklist
        history = @([pscustomobject]@{ at = $now; phase = $firstPhase; percent = 0; note = 'Task created' })
    }

    # Folder
    $ftok = @{ id = (Get-SafeName $Id 20 -KeepHyphen); module = (Get-SafeName $Module 10); type = (Get-SafeName $Type 20); title = (Get-SafeName $Title 40); code = $ShortCode }
    $folderName = (Expand-Pattern $s.ticketFolderName $ftok) -replace '[\\/:*?"<>|]', '_'
    $folder = Join-Path (Join-Path $cfg.root '01_Tickets') $folderName
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
    foreach ($sub in @($s.ticketFolders)) { New-Item -ItemType Directory -Force -Path (Join-Path $folder $sub) | Out-Null }
    $task | Add-Member -NotePropertyName '_path' -NotePropertyValue $folder -Force
    Save-SnTask $task

    # Notes
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# $Id - $Title")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("| | |`r`n|---|---|")
    foreach ($row in @(@('Module',$Module),@('Type',$Type),@('Priority',$Priority),@('Due',$Due),@('Requester',$Requester),@('Created',$now),@('Branch',$branch))) {
        [void]$sb.AppendLine("| $($row[0]) | $($row[1]) |")
    }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## Description')
    [void]$sb.AppendLine($Description)
    if ($detailList.Count) {
        [void]$sb.AppendLine(''); [void]$sb.AppendLine('## Details')
        foreach ($d in $detailList) { [void]$sb.AppendLine("- **$($d.q):** $($d.a)") }
    }
    if ($objects.Count) {
        [void]$sb.AppendLine(''); [void]$sb.AppendLine('## Proposed object names')
        foreach ($o in $objects) { [void]$sb.AppendLine("- ``$o``") }
    }
    [void]$sb.AppendLine(''); [void]$sb.AppendLine('## Open questions for the business  (tracked in task.json - answer from the dashboard)')
    foreach ($q in $questions) { [void]$sb.AppendLine("- [ ] $($q.q)") }
    foreach ($sec in @($s.notesSections | Where-Object { "$_".Trim() })) {
        [void]$sb.AppendLine(''); [void]$sb.AppendLine("## $sec"); [void]$sb.AppendLine('- ')
    }
    [void]$sb.AppendLine(''); [void]$sb.AppendLine('## Progress log')
    [void]$sb.AppendLine("- $now | $firstPhase 0% | Task created")
    Write-Utf8 (Join-Path $folder '_NOTES.md') $sb.ToString()

    Update-SnDashboard | Out-Null
    Write-Host ''
    Write-Host "Created $Id -> $folder" -ForegroundColor Green
    Write-Host "  $($questions.Count) open questions, $($checklist.Count) checklist items. Branch: $branch"
    return [pscustomobject]@{ Id = $Id; Folder = $folder; OpenQuestions = $questions.Count; Checklist = $checklist.Count }
}

function Update-SnTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Id,
        [string]$Phase, [int]$Percent = -1, [string]$Note, [string]$Blocker, [switch]$ClearBlocker,
        [int[]]$Check, [int[]]$Uncheck, [int]$Question = 0, [string]$Answer, [hashtable]$Answers, [string]$AddQuestion,
        [string]$Due, [string]$Priority
    )
    $t = Find-SnTask $Id
    $s = Get-SnSettings
    $phases = Get-PhaseNames $s
    $phasePct = Get-PhasePct $s
    $interactive = -not ($Phase -or $Percent -ge 0 -or $Note -or $Blocker -or $ClearBlocker -or $Check -or $Uncheck -or $Question -or $Answers -or $AddQuestion -or $Due -or $Priority)

    if ($interactive) {
        Show-SnTask -Id $t.id
        Write-Host '--- Update (Enter = keep current) ---' -ForegroundColor Green
        $Phase = Read-Choice 'Phase' $phases $t.phase
        $defPct = [int]$t.percent
        if ($Phase -ne $t.phase -and $phasePct.ContainsKey($Phase) -and $phasePct[$Phase] -gt $defPct) { $defPct = $phasePct[$Phase] }
        while ($true) {
            $p = Read-Text 'Percent complete 0-100' ([string]$defPct)
            $n = 0
            if ([int]::TryParse($p, [ref]$n) -and $n -ge 0 -and $n -le 100) { $Percent = $n; break }
        }
        $Note = Read-Text 'What did you do / progress note'
        $cur = if ($t.blocker) { $t.blocker } else { 'none' }
        $b = Read-Text "Blocker (current: $cur; '-' to clear)"
        if ($b -eq '-') { $ClearBlocker = $true } elseif ($b) { $Blocker = $b }

        $open = @(); for ($i = 0; $i -lt $t.checklist.Count; $i++) { if (-not $t.checklist[$i].done) { $open += $i } }
        if ($open.Count) {
            Write-Host 'Checklist - open items:' -ForegroundColor Cyan
            foreach ($i in $open) { Write-Host ("  {0}) {1}" -f ($i + 1), $t.checklist[$i].item) }
            $c = Read-Text 'Numbers completed now (e.g. 1,3) or Enter'
            if ($c) { $Check = @($c -split '[,; ]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }) }
        }
        $unans = @(); for ($i = 0; $i -lt $t.questions.Count; $i++) { if (-not $t.questions[$i].answered) { $unans += $i } }
        while ($unans.Count) {
            Write-Host 'Open questions:' -ForegroundColor Cyan
            foreach ($i in $unans) { Write-Host ("  {0}) {1}" -f ($i + 1), $t.questions[$i].q) }
            $qn = Read-Text 'Answer question number (Enter = skip)'
            if (-not ($qn -match '^\d+$')) { break }
            $idx = [int]$qn - 1
            if ($unans -notcontains $idx) { continue }
            $ans = Read-Text "  Answer"
            if ($ans) {
                $t.questions[$idx].answered = $true; $t.questions[$idx].answer = $ans
                Add-NotesLog $t "$(Get-Now) | ANSWER Q$($idx+1): $($t.questions[$idx].q) -> $ans"
                $unans = @($unans | Where-Object { $_ -ne $idx })
            }
        }
        $AddQuestion = Read-Text 'New open question to track (Enter = none)'
    }

    $changes = @()
    if ($Phase) {
        $mp = @($phases | Where-Object { $_ -ieq $Phase })
        if (-not $mp.Count) { throw "Phase must be one of: $($phases -join ', ')" }
        if ($mp[0] -ne $t.phase) { $changes += "phase $($t.phase) -> $($mp[0])" }
        $t.phase = $mp[0]
        if ($Percent -lt 0 -and $phasePct.ContainsKey($t.phase) -and $phasePct[$t.phase] -gt [int]$t.percent) { $Percent = $phasePct[$t.phase] }
    }
    if ($Percent -ge 0) {
        if ($Percent -gt 100) { $Percent = 100 }
        $t.percent = $Percent
    }
    if ($ClearBlocker) { if ($t.blocker) { $changes += 'blocker cleared' }; $t.blocker = '' }
    elseif ($Blocker) { $t.blocker = $Blocker; $changes += "BLOCKER: $Blocker" }
    foreach ($n in @($Check)) { if ($n -ge 1 -and $n -le $t.checklist.Count) { $t.checklist[$n - 1].done = $true; $changes += "done: $($t.checklist[$n - 1].item)" } }
    foreach ($n in @($Uncheck)) { if ($n -ge 1 -and $n -le $t.checklist.Count) { $t.checklist[$n - 1].done = $false; $changes += "reopened: $($t.checklist[$n - 1].item)" } }
    if ($Question -ge 1 -and $Question -le $t.questions.Count -and $Answer) {
        $t.questions[$Question - 1].answered = $true; $t.questions[$Question - 1].answer = $Answer
        $changes += "answered Q${Question}: $Answer"
    }
    if ($Answers) {
        foreach ($k in $Answers.Keys) {
            $n = [int]$k; $a = [string]$Answers[$k]
            if ($n -ge 1 -and $n -le $t.questions.Count -and $a) {
                $t.questions[$n - 1].answered = $true; $t.questions[$n - 1].answer = $a
                $changes += "answered Q${n}: $a"
            }
        }
    }
    if ($AddQuestion) {
        $t.questions = @($t.questions) + [pscustomobject]@{ q = $AddQuestion; answered = $false; answer = '' }
        $changes += "new question: $AddQuestion"
    }
    if ($Due) { $t.due = ConvertTo-SnDate $Due; $changes += "due $($t.due)" }
    if ($Priority) { $t.priority = $Priority; $changes += "priority $($t.priority)" }

    $now = Get-Now
    $t.updated = $now
    $noteText = (@($Note) + $changes | Where-Object { $_ }) -join '; '
    $t.history = @($t.history) + [pscustomobject]@{ at = $now; phase = $t.phase; percent = $t.percent; note = $noteText }
    Save-SnTask $t
    Add-NotesLog $t "$now | $($t.phase) $($t.percent)% | $noteText"
    Update-SnDashboard | Out-Null
    Write-Host "Updated $($t.id): $($t.phase) $($t.percent)%" -ForegroundColor Green
}

function Get-SnTask {
    [CmdletBinding()]
    param([switch]$All)
    $list = Get-SnTaskList -IncludeArchive:$All
    $list | Sort-Object @{e={ if ($_.phase -eq 'Done') {1} else {0} }}, priority, @{e={ if ($_.due) { $_.due } else { '9999' } }} |
        Select-Object @{n='Id';e={$_.id}}, @{n='Pri';e={$_.priority}}, @{n='Mod';e={$_.module}}, @{n='Type';e={$_.type}},
                      @{n='Phase';e={$_.phase}}, @{n='%';e={$_.percent}}, @{n='Due';e={$_.due}},
                      @{n='Q';e={ @($_.questions | Where-Object { -not $_.answered }).Count }},
                      @{n='Blocker';e={ if ($_.blocker) { 'YES' } else { '' } }}, @{n='Title';e={$_.title}}
}

function Show-SnTask {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Id)
    $t = Find-SnTask $Id -IncludeArchive
    Write-Host ''
    Write-Host "$($t.id) - $($t.title)" -ForegroundColor Green
    Write-Host "  $($t.module) | $($t.type) | $($t.priority) | Due: $($t.due) | Requester: $($t.requester)"
    Write-Host "  Phase: $($t.phase)  $($t.percent)%   Updated: $($t.updated)"
    if ($t.blocker) { Write-Host "  BLOCKER: $($t.blocker)" -ForegroundColor Red }
    Write-Host "  Folder: $($t._path)" -ForegroundColor DarkGray
    if ($t.description) { Write-Host "  $($t.description)" }
    if (@($t.details).Count) { Write-Host 'Details:' -ForegroundColor Cyan; foreach ($d in $t.details) { Write-Host "  - $($d.q): $($d.a)" } }
    if (@($t.objects).Count) { Write-Host 'Objects:' -ForegroundColor Cyan; foreach ($o in $t.objects) { Write-Host "  - $o" } }
    Write-Host 'Open questions:' -ForegroundColor Cyan
    for ($i = 0; $i -lt @($t.questions).Count; $i++) {
        $q = $t.questions[$i]
        if ($q.answered) { Write-Host ("  {0}) [x] {1} -> {2}" -f ($i + 1), $q.q, $q.answer) -ForegroundColor DarkGray }
        else { Write-Host ("  {0}) [ ] {1}" -f ($i + 1), $q.q) -ForegroundColor Yellow }
    }
    Write-Host 'Checklist:' -ForegroundColor Cyan
    for ($i = 0; $i -lt @($t.checklist).Count; $i++) {
        $c = $t.checklist[$i]
        $mark = if ($c.done) { 'x' } else { ' ' }
        Write-Host ("  {0}) [{1}] {2}" -f ($i + 1), $mark, $c.item)
    }
    Write-Host 'Last updates:' -ForegroundColor Cyan
    foreach ($h in (@($t.history) | Select-Object -Last 5)) { Write-Host "  $($h.at) | $($h.phase) $($h.percent)% | $($h.note)" }
    Write-Host ''
}

function Close-SnTask {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Id, [string]$Note = 'Closed')
    $t = Find-SnTask $Id
    $cfg = Get-SnConfig
    $now = Get-Now
    $t.phase = 'Done'; $t.percent = 100; $t.blocker = ''; $t.closed = $now; $t.updated = $now
    $t.history = @($t.history) + [pscustomobject]@{ at = $now; phase = 'Done'; percent = 100; note = $Note }
    Save-SnTask $t
    Add-NotesLog $t "$now | Done 100% | $Note"
    $dest = Join-Path (Join-Path $cfg.root '99_Archive') (Get-Date).Year
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Move-Item -Path $t._path -Destination $dest
    Update-SnDashboard | Out-Null
    Write-Host "Closed $($t.id) and archived to $dest" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Files: save scripts/documents to the right place for a task
# ---------------------------------------------------------------------------

function Assert-UnderRoot([string]$Path) {
    $root = [IO.Path]::GetFullPath((Get-SnConfig).root).TrimEnd('\') + '\'
    $full = [IO.Path]::GetFullPath($Path)
    if (-not ($full + '\').StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) { throw "Path is outside $root" }
    return $full
}

function Resolve-SnTarget($Task, [int]$Target, [string]$SubFolder) {
    $s = Get-SnSettings
    $targets = @($s.saveTargets)
    if ($Target -lt 0 -or $Target -ge $targets.Count) { throw 'Unknown save destination.' }
    $tg = $targets[$Target]
    $p = [string]$tg.path
    if ($p -match '^\{ticket\}') { $base = $Task._path; $p = $p -replace '^\{ticket\}[\\/]?', '' }
    else { $base = (Get-SnConfig).root }
    $p = Expand-Pattern $p @{ id = (Get-SafeName $Task.id 20 -KeepHyphen); module = $Task.module; type = (Get-SafeName $Task.type 20) }
    $dir = if ($p) { Join-Path $base $p } else { $base }
    if ($SubFolder) { Test-RelPath $SubFolder 'Sub-folder'; $dir = Join-Path $dir $SubFolder }
    return [pscustomobject]@{ Dir = (Assert-UnderRoot $dir); Target = $tg }
}

function Get-SnTargetFolders {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Id, [int]$Target = 0)
    $t = Find-SnTask $Id -IncludeArchive
    $r = Resolve-SnTarget $t $Target ''
    $list = @()
    if (Test-Path $r.Dir) {
        $list = @(Get-ChildItem -Path $r.Dir -Directory -Recurse -Depth 2 -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notlike '.*' } |
            ForEach-Object { $_.FullName.Substring($r.Dir.Length).TrimStart('\') } | Sort-Object)
    }
    return [pscustomobject]@{ base = $r.Dir; exists = (Test-Path $r.Dir); folders = $list; prefix = [bool]$r.Target.prefix }
}

function Save-SnFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Id, [int]$Target = 0, [string]$SubFolder,
        [Parameter(Mandatory)][string]$FileName, [string]$Base64, [string]$Text,
        [switch]$AddPrefix, [switch]$AddHeader, [string]$Purpose
    )
    $t = Find-SnTask $Id -IncludeArchive
    $r = Resolve-SnTarget $t $Target $SubFolder
    $name = ([IO.Path]::GetFileName($FileName.Trim()) -replace '[\\/:*?"<>|]', '_').Trim()
    if (-not $name) { throw 'File name is required.' }
    New-Item -ItemType Directory -Force -Path $r.Dir | Out-Null

    if ($AddPrefix -and -not $name.StartsWith("$($t.id)_", [StringComparison]::OrdinalIgnoreCase)) {
        $rx = '^' + [regex]::Escape($t.id) + '_(\d+)_'
        $max = 0
        foreach ($f in Get-ChildItem -Path $r.Dir -File) { if ($f.Name -match $rx) { $max = [Math]::Max($max, [int]$Matches[1]) } }
        $name = '{0}_{1:D2}_{2}' -f $t.id, ($max + 1), $name
    }
    $path = Join-Path $r.Dir $name
    $stem = [IO.Path]::GetFileNameWithoutExtension($name); $ext = [IO.Path]::GetExtension($name); $v = 2
    while (Test-Path $path) { $path = Join-Path $r.Dir ('{0}_v{1}{2}' -f $stem, $v, $ext); $v++ }

    if ($PSBoundParameters.ContainsKey('Text')) {
        $body = $Text -replace "`r?`n", "`r`n"
        $sqlLike = @('.sql', '.pks', '.pkb', '.pls', '.prc', '.fnc', '.trg', '.vw', '.ctl') -contains $ext.ToLower()
        if ($AddHeader -and $sqlLike) {
            $hdr = @(
                '-- ============================================================================',
                "-- Ticket : $($t.id) - $($t.title)",
                "-- File   : $([IO.Path]::GetFileName($path))",
                "-- Purpose: $Purpose",
                "-- Created: $(Get-Now)",
                '-- ============================================================================', '') -join "`r`n"
            $body = $hdr + $body
        }
        Write-Utf8 $path $body
    } elseif ($Base64) {
        [IO.File]::WriteAllBytes($path, [Convert]::FromBase64String($Base64))
    } else { throw 'Nothing to save (no content).' }

    # Record it on the task
    $now = Get-Now
    $rel = $path.Substring([IO.Path]::GetFullPath((Get-SnConfig).root).TrimEnd('\').Length).TrimStart('\')
    if (-not ($t.PSObject.Properties.Name -contains 'files')) { $t | Add-Member -NotePropertyName 'files' -NotePropertyValue @() }
    $t.files = @($t.files) + [pscustomobject]@{ at = $now; path = $rel; target = $r.Target.name }
    $t.updated = $now
    $t.history = @($t.history) + [pscustomobject]@{ at = $now; phase = $t.phase; percent = $t.percent; note = "Saved file: $rel" }
    Save-SnTask $t
    Add-NotesLog $t "$now | FILE | $rel  ($($r.Target.name))"
    Update-SnDashboard | Out-Null
    return [pscustomobject]@{ path = $path; relative = $rel }
}

function Get-SnTaskFiles {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Id)
    $t = Find-SnTask $Id -IncludeArchive
    $rootLen = [IO.Path]::GetFullPath((Get-SnConfig).root).TrimEnd('\').Length
    $inTicket = @(Get-ChildItem -Path $t._path -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne 'task.json' -and $_.Name -ne '.gitkeep' } | Sort-Object FullName |
        ForEach-Object { [pscustomobject]@{ rel = $_.FullName.Substring($t._path.Length).TrimStart('\'); path = $_.FullName.Substring($rootLen).TrimStart('\'); size = $_.Length; modified = $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm') } })
    $root = (Get-SnConfig).root
    $elsewhere = @(@($t.files) | Where-Object { $_ -and $_.path } | Where-Object { -not (Join-Path $root $_.path).StartsWith($t._path, [StringComparison]::OrdinalIgnoreCase) } |
        ForEach-Object { [pscustomobject]@{ path = $_.path; target = $_.target; at = $_.at; exists = (Test-Path (Join-Path $root $_.path)) } })
    return [pscustomobject]@{ ticket = $inTicket; elsewhere = $elsewhere }
}

function Open-SnPath {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path, [switch]$ShowInFolder)
    $root = (Get-SnConfig).root
    $full = if ([IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $root $Path }
    $full = Assert-UnderRoot $full
    if (-not (Test-Path $full)) { throw "Not found: $full" }
    if ($ShowInFolder) { Start-Process explorer.exe "/select,`"$full`"" } else { Start-Process $full }
}

function Get-SnMeta {
    $s = Get-SnSettings
    $tq = @{}; $tobj = @{}
    foreach ($t in $s.types) {
        $tq[$t.name] = @($t.questions | ForEach-Object { [pscustomobject]@{ k = $_.k; q = $_.q; d = [string]$_.d } })
        $tobj[$t.name] = (@($t.objects | Where-Object { $_ }).Count -gt 0)
    }
    return [pscustomobject]@{
        modules = @($s.modules); types = @($s.types | ForEach-Object { $_.name }); priorities = @($s.priorities)
        defaultPriority = $s.defaultPriority; phases = @(Get-PhaseNames $s); phasePct = (Get-PhasePct $s)
        typeQuestions = $tq; typeHasObjects = $tobj; prefix = $s.prefix; root = (Get-SnConfig).root
        career = $s.career
        appearance = $s.appearance
        saveTargets = @($s.saveTargets | ForEach-Object { [pscustomobject]@{ name = $_.name; path = $_.path; prefix = [bool]$_.prefix } })
        pack = (Get-SnMetaPack)
    }
}

function Get-SnMetaPack {
    # what the page needs from the career pack: its name, area names and the ui wording (labels, placeholders, skill rules)
    $pack = $null
    try { $pack = Get-SnPackOrLegacy } catch { }
    if (-not $pack) { return $null }
    $names = [ordered]@{}
    foreach ($a in @($pack.areas | Where-Object { $_ })) { $names["$($a.id)"] = "$($a.name)" }
    return [pscustomobject]@{ id = $pack.id; name = $pack.name; areaNames = [pscustomobject]$names; ui = $pack.ui }
}

function Get-SnDashboardHtml([switch]$Live) {
    $tasks = @(Get-SnTaskList -IncludeArchive)
    $json = ConvertTo-Json -InputObject $tasks -Depth 8 -Compress
    if (-not $tasks.Count) { $json = '[]' }
    $metaObj = Get-SnMeta
    $meta = $metaObj | ConvertTo-Json -Depth 12 -Compress
    $liveJs = if ($Live) { 'true' } else { 'false' }
    $tpl = [IO.File]::ReadAllText((Join-Path $script:ToolDir 'dashboard_template.html'))
    $learn = Get-SnLearn | ConvertTo-Json -Depth 8 -Compress
    return $tpl.Replace('/*__DATA__*/[]', $json).Replace('/*__META__*/{}', $meta).Replace('/*__LIVE__*/false', $liveJs).Replace('/*__LEARN__*/{}', $learn).
        Replace('__GENERATED__', (Get-Now)).Replace('__PREFIX__', $metaObj.prefix)
}

function Update-SnDashboard {
    [CmdletBinding()]
    param([switch]$Open)
    $cfg = Get-SnConfig
    $out = Join-Path $cfg.root 'Dashboard.html'
    try { Sync-SnKnowledge | Out-Null } catch { Write-Warning "Knowledge sync failed: $($_.Exception.Message)" }
    Write-Utf8 $out (Get-SnDashboardHtml)
    if ($Open) { Start-Process $out }
    return $out
}

function Start-SnMenu {
    while ($true) {
        Write-Host ''
        Write-Host '================== STRANOTE ==================' -ForegroundColor Green
        $active = @(Get-SnTaskList)
        $blocked = @($active | Where-Object { $_.blocker }).Count
        $today = (Get-Date).ToString('yyyy-MM-dd')
        $overdue = @($active | Where-Object { $_.due -and $_.due -lt $today }).Count
        Write-Host ("  Active: {0}   Blocked: {1}   Overdue: {2}" -f $active.Count, $blocked, $overdue)
        Write-Host '  1) New task        2) Update progress   3) List tasks'
        Write-Host '  4) Show task       5) Close task        6) Open dashboard (incl. Settings)'
        Write-Host '  7) Open ticket folder                    0) Exit'
        $c = Read-Host 'Choose'
        try {
            switch ($c) {
                '1' { New-SnTask | Out-Null }
                '2' { Get-SnTask | Format-Table -AutoSize | Out-Host; $id = Read-Text 'Task ID' -Required; Update-SnTask -Id $id }
                '3' { Get-SnTask | Format-Table -AutoSize | Out-Host }
                '4' { $id = Read-Text 'Task ID' -Required; Show-SnTask -Id $id }
                '5' { Get-SnTask | Format-Table -AutoSize | Out-Host; $id = Read-Text 'Task ID to close' -Required; $n = Read-Text 'Closing note' 'Closed'; Close-SnTask -Id $id -Note $n }
                '6' { Start-Process (Join-Path (Get-SnConfig).root 'dashboard.cmd') }
                '7' { $id = Read-Text 'Task ID' -Required; Start-Process (Find-SnTask $id -IncludeArchive)._path }
                '0' { return }
                default { }
            }
        } catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }
    }
}

. (Join-Path $PSScriptRoot 'StranoteLearn.ps1')
. (Join-Path $PSScriptRoot 'StranoteTeach.ps1')
. (Join-Path $PSScriptRoot 'StranoteReview.ps1')
. (Join-Path $PSScriptRoot 'StranotePacks.ps1')
. (Join-Path $PSScriptRoot 'StranoteMigrate.ps1')
. (Join-Path $PSScriptRoot 'StranoteOnboarding.ps1')
. (Join-Path $PSScriptRoot 'StranoteAliases.ps1')

$script:SnExports = @(
    'Test-SnPack', 'Get-SnPack', 'Get-SnPackList', 'Get-SnProfile', 'Save-SnProfile', 'Get-SnActivePack', 'Get-SnPackOrLegacy', 'New-SnPackRequest', 'Get-SnPackRequest', 'Approve-SnPackDraft', 'Deny-SnPackDraft', 'Submit-SnPackDraft', 'Get-SnEffectiveSettings', 'Get-SnBaseSettings', 'Get-SnOverrides', 'Get-SnDiff', 'Merge-SnObject', 'ConvertTo-SnCanonicalJson', 'Get-SnConfigPath', 'Get-SnLearnDirFor', 'Get-SnLearnDir', 'Invoke-SnMigration', 'Get-SnSnapshot', 'Compare-SnSnapshot', 'Get-SnExtractors', 'Copy-SnJson', 'Get-SnOnboarding', 'Save-SnOnboarding', 'Restart-SnOnboarding', 'Complete-SnOnboarding', 'New-SnFirstWeekPlan', 'Get-SnPlan', 'Set-SnPlanItem',
    'Set-SnCard', 'Remove-SnCard', 'Set-SnCardKeep', 'Sync-SnKnowledge', 'Get-SnArabic', 'Set-SnArabic', 'Set-SnShotRequests', 'Add-SnShot', 'Remove-SnShot', 'Set-SnCardCategory', 'Test-SnQuestionReady', 'Set-SnConceptStatus', 'Set-SnLesson', 'Remove-SnLesson', 'Save-SnLessonProgress', 'Add-SnFollowup', 'Set-SnFollowupAnswer', 'Get-SnTeach', 'Get-SnPendingFollowups', 'Get-SnDailyReview', 'Save-SnReviewDay', 'Get-SnReviewStreak', 'Add-SnQuestions', 'Remove-SnQuestion', 'Submit-SnAnswer', 'Get-SnCv', 'Save-SnCv', 'Add-SnCvBullet', 'Export-SnCv', 'Get-SnLearn', 'Get-SnSuggestions', 'New-SnTask', 'Update-SnTask', 'Get-SnTask', 'Show-SnTask', 'Close-SnTask', 'Update-SnDashboard', 'Get-SnDashboardHtml', 'Start-SnMenu', 'Get-SnTaskList', 'Find-SnTask', 'Get-SnMeta', 'Get-SnConfig', 'Get-SnSettings', 'Save-SnSettings', 'Reset-SnSettings', 'Restore-SnSettingsBackup', 'Get-SnTargetFolders', 'Save-SnFile', 'Get-SnTaskFiles', 'Open-SnPath'
)
