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
$script:MaxFileBytes = 50 * 1048576   # one saved file or attachment (the page checks the same limit)

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
        $ie = @(Get-SnIntakeErrors $t)
        if ($ie.Count) { throw "$($ie[0])." }
        $le = @(Get-SnLayoutErrors $t)
        if ($le.Count) { throw "$("$($le[0])".TrimEnd('.'))." }
    }
    if ("$($s.attachmentsPath)") {
        if ("$($s.attachmentsPath)" -notmatch '^\{ticket\}') { throw 'Attachments folder must start with {ticket} (inside the task folder).' }
        $rel = ("$($s.attachmentsPath)" -replace '^\{ticket\}[\\/]?', '') -replace '\{(id|module|type)\}', 'x'
        if ($rel) { Test-RelPath $rel 'Attachments folder' }
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
        if ($null -ne $t.versioned -and $t.versioned -isnot [bool]) { throw "Save destination '$($t.name)': versioned must be true or false." }
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
            foreach ($sub in @((Get-SnTypeLayout $Settings (Get-TypeDef $Settings $t.type)).folders)) {
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
# Intake: question kinds, conditions (when) and variants of a task type
# Spec: specs/004-task-attachments-report-intake (contracts/intake-fields.md)
# ---------------------------------------------------------------------------

$script:IntakeKinds = @('text', 'long', 'choice', 'files')

function Get-SnQuestionKind($Q) { if ("$($Q.kind)") { return "$($Q.kind)".ToLower() } else { return 'text' } }

function Get-SnWhenValues($When) {
    # the answer values a condition accepts: { k, is } or { k, in: [] }
    if ($null -ne $When.in) { return @(@($When.in) | ForEach-Object { "$_" }) }
    return @("$($When.is)")
}

function Get-SnWhenErrors($When, [hashtable]$Choices, [hashtable]$Depth, [string]$At) {
    $errs = @()
    $k = "$($When.k)"
    if (-not $Choices.ContainsKey($k)) { return @("${At}: when.k '$k' is not an earlier choice question") }
    if ($null -ne $When.in -and "$($When.is)") { $errs += "${At}: when needs 'is' or 'in', not both" }
    $vals = @(Get-SnWhenValues $When)
    if (-not @($vals | Where-Object { $_ }).Count) { $errs += "${At}: when needs a value ('is' or 'in')" }
    foreach ($v in $vals) { if ($v -and -not @($Choices[$k] | Where-Object { $_ -ieq $v }).Count) { $errs += "${At}: when value '$v' is not an option of '$k'" } }
    if ($Depth[$k] -ge 2) { $errs += "${At}: conditions may be at most 2 levels deep" }
    return $errs
}

function Get-SnIntakeErrors($Type) {
    <# Errors in a task type's intake fields (kind, options, required, when, askIfBlank, sub) and variants; empty = valid.
       Questions without the new fields are always valid. Used by Test-SnPack and Assert-SnSettings. #>
    $errs = @()
    $choices = @{}; $depth = @{}
    foreach ($q in @(@($Type.questions) | Where-Object { $_ })) {
        $at = "Type '$($Type.name)', question '$($q.k)'"
        $kind = Get-SnQuestionKind $q
        $opts = @(@($q.options) | Where-Object { $null -ne $_ } | ForEach-Object { "$_".Trim() })
        if ($script:IntakeKinds -notcontains $kind) { $errs += "${at}: kind must be one of $($script:IntakeKinds -join ', ')" }
        if ($kind -eq 'choice') {
            if ($opts.Count -lt 2 -or $opts.Count -gt 30) { $errs += "${at}: a choice needs 2 to 30 options" }
            elseif (@($opts | Where-Object { -not $_ }).Count) { $errs += "${at}: an option is empty" }
            elseif (@($opts | ForEach-Object { $_.ToLower() } | Select-Object -Unique).Count -ne $opts.Count) { $errs += "${at}: options must be unique" }
            elseif ("$($q.d)" -and -not @($opts | Where-Object { $_ -ieq "$($q.d)" }).Count) { $errs += "${at}: default '$($q.d)' is not one of the options" }
        } elseif ($opts.Count) { $errs += "${at}: options are only for kind 'choice'" }
        if ($kind -eq 'files') {
            if ($q.required) { $errs += "${at}: a files question cannot be required" }
            if ("$($q.askIfBlank)") { $errs += "${at}: askIfBlank is not for files questions" }
            if ("$($q.sub)") { try { Test-RelPath "$($q.sub)" "$at sub-folder" } catch { $errs += $_.Exception.Message } }
        } elseif ("$($q.sub)") { $errs += "${at}: sub is only for kind 'files'" }
        $d = 0
        if ($q.when) {
            $errs += @(Get-SnWhenErrors $q.when $choices $depth $at)
            if ($depth.ContainsKey("$($q.when.k)")) { $d = $depth["$($q.when.k)"] + 1 }
        }
        if ($kind -eq 'choice') { $choices["$($q.k)"] = $opts; $depth["$($q.k)"] = $d }
    }
    $vs = @(@($Type.variants) | Where-Object { $_ })
    for ($i = 0; $i -lt $vs.Count; $i++) {
        $at = "Type '$($Type.name)', variant $($i + 1)"
        if (-not $vs[$i].when) { $errs += "${at}: when is required"; continue }
        $errs += @(Get-SnWhenErrors $vs[$i].when $choices @{} $at)
        foreach ($l in 'openQuestions', 'checklist', 'objects') {
            if (@(@($vs[$i].$l) | Where-Object { $null -ne $_ -and -not "$_".Trim() }).Count) { $errs += "${at}: $l has an empty item" }
        }
    }
    return $errs   # callers wrap the result in @()
}

function Test-SnWhen($When, [hashtable]$Answers) {
    $a = "$($Answers["$($When.k)"])"
    return [bool](@(Get-SnWhenValues $When | Where-Object { $_ -and $_ -ieq $a }).Count)
}

function Resolve-SnIntake($TypeDef, [hashtable]$Answers) {
    <# Applies a type's intake rules to the answers (key -> text). Returns:
       visible   questions shown for these answers (in order; a question whose condition's question is hidden is hidden)
       details   { q, a, k } for visible non-file questions with an answer (choice answers in the option's spelling)
       variant   the first variant whose condition matches, or $null
       askBusiness open questions from askIfBlank of visible blank questions
       errors    required visible questions left blank, choice answers that are not an option #>
    if (-not $Answers) { $Answers = @{} }
    $shown = @{}; $visible = @(); $details = @(); $ask = @(); $errs = @()
    $clean = @{}
    foreach ($q in @(@($TypeDef.questions) | Where-Object { $_ -and $_.k })) {
        $k = "$($q.k)"
        if ($q.when) {
            $wk = "$($q.when.k)"
            if (-not $shown.ContainsKey($wk) -or -not (Test-SnWhen $q.when $clean)) { continue }
        }
        $shown[$k] = $true; $visible += $q
        $kind = Get-SnQuestionKind $q
        if ($kind -eq 'files') { continue }
        $val = if ($Answers.ContainsKey($k)) { "$($Answers[$k])".Trim() } else { '' }
        if ($kind -eq 'choice' -and $val) {
            $m = @(@($q.options) | Where-Object { "$_" -ieq $val })
            if ($m.Count) { $val = "$($m[0])" } else { $errs += "'$($q.q)': '$val' is not one of: $(@($q.options) -join ', ')"; $val = '' }
        }
        $clean[$k] = $val
        if ($val) { $details += [pscustomobject]@{ q = $q.q; a = $val; k = $k } }
        else {
            if ($q.required) { $errs += "'$($q.q)' needs an answer" }
            if ("$($q.askIfBlank)".Trim()) { $ask += "$($q.askIfBlank)".Trim() }
        }
    }
    $variant = $null
    foreach ($v in @(@($TypeDef.variants) | Where-Object { $_ -and $_.when })) {
        if ($shown.ContainsKey("$($v.when.k)") -and (Test-SnWhen $v.when $clean)) { $variant = $v; break }
    }
    return [pscustomobject]@{ visible = $visible; details = $details; variant = $variant; askBusiness = $ask; errors = $errs }
}

function Get-SnTypeList($TypeDef, $Variant, [string]$Name) {
    # a variant's list replaces the type's own when the variant defines it
    if ($Variant -and $null -ne $Variant.$Name) { return @($Variant.$Name) }
    return @($TypeDef.$Name)
}

# ---------------------------------------------------------------------------
# Type layout: a task type's own sub-folders, save places, attachments folder and general lists; file versions
# Spec: specs/005-task-type-layouts-versions (contracts/type-layout.md)
# ---------------------------------------------------------------------------

function Get-SnTicketPathErrors([string]$Path, [string]$At) {
    # a pattern inside the task folder: starts with {ticket}, the rest a safe relative folder (tokens allowed)
    if ($Path -notmatch '^\{ticket\}') { return @("${At} must start with {ticket} (inside the task folder)") }
    $rel = ($Path -replace '^\{ticket\}[\\/]?', '') -replace '\{(id|module|type)\}', 'x'
    if ($rel) { try { Test-RelPath $rel $At } catch { return @($_.Exception.Message) } }
    return @()
}

function Get-SnLayoutErrors($Type) {
    <# Errors in a task type's layout fields (folders, saveTargets, attachmentsPath, useBaseChecklist,
       useCommonQuestions); empty = valid. Types without them are always valid. Used by Test-SnPack and Assert-SnSettings. #>
    $errs = @()
    $at = "Type '$($Type.name)'"
    $fs = @(@($Type.folders) | Where-Object { $null -ne $_ } | ForEach-Object { "$_".Trim() })
    if ($fs.Count -gt 20) { $errs += "${at}: at most 20 folders" }
    foreach ($f in $fs) { try { Test-RelPath $f "$at folder" } catch { $errs += $_.Exception.Message } }
    if (@($fs | ForEach-Object { $_.ToLower() } | Select-Object -Unique).Count -ne $fs.Count) { $errs += "${at}: folders must be unique" }
    $st = @(@($Type.saveTargets) | Where-Object { $_ })
    for ($i = 0; $i -lt $st.Count; $i++) {
        $n = "$($st[$i].name)".Trim()
        if (-not $n) { $errs += "${at}: save place $($i + 1) has no name"; continue }
        $errs += @(Get-SnTicketPathErrors "$($st[$i].path)" "$at save place '$n'")
        if ($null -ne $st[$i].versioned -and $st[$i].versioned -isnot [bool]) { $errs += "$at save place '$n': versioned must be true or false" }
    }
    if ("$($Type.attachmentsPath)") { $errs += @(Get-SnTicketPathErrors "$($Type.attachmentsPath)" "$at attachments folder") }
    foreach ($f in 'useBaseChecklist', 'useCommonQuestions') {
        if ($null -ne $Type.$f -and $Type.$f -isnot [bool]) { $errs += "${at}: $f must be true or false" }
    }
    return $errs   # callers wrap the result in @()
}

function Get-SnTypeLayout($s, $TypeDef) {
    <# The layout of a task type; each field falls back to the general setting:
       folders      the type's folders, else settings.ticketFolders (an empty list = the general ones)
       saveTargets  the type's places + the general places outside the task folder, else all general places
       attachmentsPath  the type's, else settings.attachmentsPath, else {ticket}\Attachments
       useBaseChecklist / useCommonQuestions  false only when the type says so #>
    $folders = @(@($TypeDef.folders) | Where-Object { "$_".Trim() })
    if (-not $folders.Count) { $folders = @(@($s.ticketFolders) | Where-Object { "$_".Trim() }) }
    $own = @(@($TypeDef.saveTargets) | Where-Object { $_ -and "$($_.name)".Trim() })
    if ($own.Count) { $targets = @($own) + @(@($s.saveTargets) | Where-Object { $_ -and "$($_.path)" -notmatch '^\{ticket\}' }) }
    else { $targets = @(@($s.saveTargets) | Where-Object { $_ }) }
    $ap = "$($TypeDef.attachmentsPath)"
    if (-not $ap) { $ap = "$($s.attachmentsPath)" }
    if (-not $ap) { $ap = '{ticket}\Attachments' }
    return [pscustomobject]@{
        folders = $folders; saveTargets = $targets; attachmentsPath = $ap
        useBaseChecklist = ($TypeDef.useBaseChecklist -ne $false); useCommonQuestions = ($TypeDef.useCommonQuestions -ne $false)
    }
}

function Get-SnTaskTargets($Task, $s) {
    # the save places of a task (its type's layout); the page and the API index into this list
    if (-not $s) { $s = Get-SnSettings }
    return @((Get-SnTypeLayout $s (Get-TypeDef $s $Task.type)).saveTargets)
}

function Get-SnFileFamily([string]$Name) {
    # family and version of a file name: 'x_v3.sql' -> x, 3; 'x.sql' -> x, 1
    $ext = [IO.Path]::GetExtension($Name); $stem = [IO.Path]::GetFileNameWithoutExtension($Name)
    if ($stem -match '^(.+?)_[vV](\d{1,3})$' -and [int]$Matches[2] -ge 1) { return [pscustomobject]@{ family = $Matches[1]; version = [int]$Matches[2]; ext = $ext } }
    return [pscustomobject]@{ family = $stem; version = 1; ext = $ext }
}

function Get-SnDirFamilies([string]$Dir) {
    # the file families of one folder (not its sub-folders), newest first: { family, latest, version, versions, at, ext }
    $fam = @{}
    if (Test-Path -LiteralPath $Dir -PathType Container) {
        foreach ($f in Get-ChildItem -LiteralPath $Dir -File | Where-Object { @('task.json', '_NOTES.md') -notcontains $_.Name -and $_.Name -notlike '.*' }) {
            $x = Get-SnFileFamily $f.Name
            $key = $x.family.ToLower()
            if (-not $fam.ContainsKey($key)) { $fam[$key] = @{ family = $x.family; version = 0; versions = 0; file = $null } }
            $e = $fam[$key]; $e.versions++
            if ($x.version -gt $e.version) { $e.version = $x.version; $e.family = $x.family; $e.file = $f }
        }
    }
    return @($fam.Values | Sort-Object { $_.file.LastWriteTime } -Descending | ForEach-Object {
        [pscustomobject]@{ family = $_.family; latest = $_.file.Name; version = $_.version; versions = $_.versions
            at = $_.file.LastWriteTime.ToString('yyyy-MM-dd HH:mm'); ext = $_.file.Extension } })
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

function Read-SnOption($Q) {
    # a choice question: only one of its options is accepted
    $opts = @($Q.options | ForEach-Object { "$_" })
    while ($true) {
        $a = Read-Choice $Q.q $opts ([string]$Q.d)
        $m = @($opts | Where-Object { $_ -ieq $a })
        if ($m.Count) { return $m[0] }
        Write-Host '  Choose one of the numbers above.' -ForegroundColor Yellow
    }
}

function Read-Lines([string]$Prompt, [switch]$Required) {
    # several lines; an empty line ends
    Write-Host "$Prompt (empty line to finish)" -ForegroundColor Cyan
    while ($true) {
        $lines = @()
        while ($true) { $l = Read-Host ' '; if ([string]::IsNullOrWhiteSpace($l)) { break }; $lines += $l }
        if ($Required -and -not $lines.Count) { Write-Host '  (required)' -ForegroundColor Yellow; continue }
        return , $lines
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
        [hashtable]$Details, [string[]]$ExtraQuestions, [switch]$NonInteractive,
        [string[]]$Attach   # files to copy into the attachments folder; 'key=path' puts one under a files question
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

    # Type-specific details: only the questions shown for these answers (conditions, variants: Resolve-SnIntake).
    # Checked before an auto id is used, so a missing answer does not burn a number.
    $answers = @{}
    if ($Details) { foreach ($k in $Details.Keys) { $answers[$k] = [string]$Details[$k] } }
    $attachList = @($Attach | Where-Object { $_ })
    $qs = @($typeDef.questions | Where-Object { $_ -and $_.k })
    if ($ask -and $qs.Count) {
        Write-Host "--- $Type details ---" -ForegroundColor Green
        foreach ($q in $qs) {
            $k = "$($q.k)"
            if ($answers.ContainsKey($k)) { continue }
            if ($q.when -and -not @((Resolve-SnIntake $typeDef $answers).visible | Where-Object { "$($_.k)" -eq $k }).Count) { continue }
            switch (Get-SnQuestionKind $q) {
                'choice' { $answers[$k] = Read-SnOption $q }
                'long'   { $answers[$k] = (Read-Lines $q.q -Required:([bool]$q.required)) -join "`n" }
                'files'  { foreach ($p in (Read-Lines "$($q.q) - file paths")) { $attachList += "$k=$($p.Trim('"'))" } }
                default  { $answers[$k] = Read-Text $q.q ([string]$q.d) -Required:([bool]$q.required) }
            }
        }
    }
    $intake = Resolve-SnIntake $typeDef $answers
    if (@($intake.errors).Count) { throw "$Type details: $(@($intake.errors) -join '; ')." }
    $detailList = @($intake.details)
    if ($Details) {
        $known = @($qs | ForEach-Object { $_.k })
        foreach ($k in $Details.Keys) { if ($known -notcontains $k) { $detailList += [pscustomobject]@{ q = $k; a = [string]$Details[$k] } } }
    }
    $fileKeys = @($intake.visible | Where-Object { (Get-SnQuestionKind $_) -eq 'files' } | ForEach-Object { "$($_.k)" })

    if (-not $Id) {
        $Id = '{0}{1:D4}' -f $s.autoIdPrefix, [int]$cfg.nextAutoId
        $cfg.nextAutoId = [int]$cfg.nextAutoId + 1
        Save-SnConfig $cfg
    }
    $Id = $Id.Trim().ToUpper()
    if (@(Get-SnTaskList -IncludeArchive | Where-Object { $_.id -ieq $Id }).Count) { throw "Task '$Id' already exists." }

    $objPatterns = @(Get-SnTypeList $typeDef $intake.variant 'objects' | Where-Object { $_ })
    if (-not $ShortCode) {
        $ShortCode = Get-ShortCode $s $Title $Module
        if ($ask -and $objPatterns.Count) { $ShortCode = Read-Text 'Short code for object names' $ShortCode }
    }
    $ShortCode = (Get-SafeName $ShortCode 20).ToUpper()

    # the type's layout (spec 005) decides the sub-folders and whether the general questions / checklist are added
    $layout = Get-SnTypeLayout $s $typeDef
    $common = @(); if ($layout.useCommonQuestions) { $common = @($s.commonQuestions) }
    $base = @(); if ($layout.useBaseChecklist) { $base = @($s.baseChecklist) }
    $questions = @()
    foreach ($q in (@(Get-SnTypeList $typeDef $intake.variant 'openQuestions') + $common + @($intake.askBusiness) + @($ExtraQuestions) | Where-Object { "$_".Trim() })) {
        $questions += [pscustomobject]@{ q = $q; answered = $false; answer = '' }
    }
    $checklist = @()
    foreach ($c in (@(Get-SnTypeList $typeDef $intake.variant 'checklist') + $base | Where-Object { "$_".Trim() })) { $checklist += [pscustomobject]@{ item = $c; done = $false } }

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
    foreach ($sub in @($layout.folders)) { New-Item -ItemType Directory -Force -Path (Join-Path $folder $sub) | Out-Null }
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
        foreach ($d in $detailList) { [void]$sb.AppendLine("- **$($d.q):** $(("$($d.a)" -replace "`r?`n", "`r`n  "))") }
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

    # Attachments: copied one by one; a file that fails is reported and does not undo the task or the other files
    $attached = 0; $failed = @()
    foreach ($a in $attachList) {
        $qk = ''; $p = "$a"
        if ($p -match '^([A-Za-z][A-Za-z0-9_]*)=(.+)$') { $qk = $Matches[1]; $p = $Matches[2] }
        $leaf = [IO.Path]::GetFileName($p)
        try {
            if ($qk -and $fileKeys -notcontains $qk) { throw "'$qk' is not a file question shown for these answers" }
            Save-SnFile -Id $Id -Attachment -Question $qk -SourcePath $p -FileName $leaf -NoRefresh | Out-Null
            $attached++
        } catch { $failed += "${leaf}: $($_.Exception.Message)"; Write-Warning "Not attached: ${leaf}: $($_.Exception.Message)" }
    }

    Update-SnDashboard | Out-Null
    Write-Host ''
    Write-Host "Created $Id -> $folder" -ForegroundColor Green
    Write-Host "  $($questions.Count) open questions, $($checklist.Count) checklist items. Branch: $branch"
    if ($attachList.Count) { Write-Host "  $attached of $($attachList.Count) attachments saved." }
    return [pscustomobject]@{ Id = $Id; Folder = $folder; OpenQuestions = $questions.Count; Checklist = $checklist.Count; Attached = $attached; AttachFailed = $failed }
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
    $targets = @(Get-SnTaskTargets $Task)
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

function Resolve-SnAttachDir($Task, [string]$Sub) {
    # attachments place inside the task folder (the type's, else settings.attachmentsPath, default {ticket}\Attachments)
    # + optional sub-folder
    $s = Get-SnSettings
    $p = (Get-SnTypeLayout $s (Get-TypeDef $s $Task.type)).attachmentsPath
    $p = Expand-Pattern ($p -replace '^\{ticket\}[\\/]?', '') @{ id = (Get-SafeName $Task.id 20 -KeepHyphen); module = $Task.module; type = (Get-SafeName $Task.type 20) }
    $dir = if ($p) { Join-Path $Task._path $p } else { $Task._path }
    if ($Sub) { Test-RelPath $Sub 'Sub-folder'; $dir = Join-Path $dir $Sub }
    return (Assert-UnderRoot $dir)
}

function Resolve-SnSaveDir($Task, [int]$Target, [string]$SubFolder, [bool]$Attachment, [string]$Question) {
    # the folder a file of this task is saved in: a save place (+ sub-folder) or the attachments place (+ the files
    # question's sub-folder + sub-folder). Returns { Dir, TargetName, Versioned }
    if ($Attachment) {
        $sub = ''
        if ($Question) {
            $fq = @(@((Get-TypeDef (Get-SnSettings) $Task.type).questions) | Where-Object { $_ -and "$($_.k)" -eq $Question -and (Get-SnQuestionKind $_) -eq 'files' })
            if (-not $fq.Count) { throw "'$Question' is not a file question of type '$($Task.type)'." }
            $sub = "$($fq[0].sub)"
        }
        if ($SubFolder) { if ($sub) { $sub = Join-Path $sub $SubFolder } else { $sub = $SubFolder } }
        return [pscustomobject]@{ Dir = (Resolve-SnAttachDir $Task $sub); TargetName = 'Attachments'; Versioned = $false }
    }
    $r = Resolve-SnTarget $Task $Target $SubFolder
    return [pscustomobject]@{ Dir = $r.Dir; TargetName = $r.Target.name; Versioned = ($r.Target.versioned -eq $true) }
}

function Get-SnFileFamilies {
    <# The file families in the folder a save would go to (same parameters as Save-SnFile), newest first, so the page
       can ask "new file or new version of ...?" before saving. Read-only. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Id, [int]$Target = 0, [string]$SubFolder, [switch]$Attachment, [string]$Question)
    $t = Find-SnTask $Id -IncludeArchive
    $d = Resolve-SnSaveDir $t $Target $SubFolder $Attachment $Question
    $rel = $d.Dir.Substring([IO.Path]::GetFullPath((Get-SnConfig).root).TrimEnd('\').Length).TrimStart('\')
    return [pscustomobject]@{ dir = $rel; versioned = $d.Versioned; families = @(Get-SnDirFamilies $d.Dir) }
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
        [switch]$AddPrefix, [switch]$AddHeader, [string]$Purpose,
        # -Attachment: save in the task's attachments place (settings.attachmentsPath) instead of save target -Target;
        # -Question: the files question it answers (its sub-folder is used); -SourcePath: copy this file (left untouched)
        [switch]$Attachment, [string]$Question, [string]$SourcePath, [switch]$NoRefresh,
        # versions (spec 005): -VersionOf <family> = the next version of that file; -AsNew = a new file, refused if the
        # name is taken; neither = the old rule (a free name _v2, _v3 ...). -Note = what changed (logged).
        [string]$VersionOf, [switch]$AsNew, [string]$Note
    )
    $t = Find-SnTask $Id -IncludeArchive
    if ($VersionOf -and $AsNew) { throw 'Choose a new version or a new file, not both.' }
    $d = Resolve-SnSaveDir $t $Target $SubFolder $Attachment $Question
    $dir = $d.Dir; $targetName = $d.TargetName
    $name = ([IO.Path]::GetFileName($FileName.Trim()) -replace '[\\/:*?"<>|]', '_').Trim()
    if (-not $name) { throw 'File name is required.' }
    $Note = ("$Note" -replace '\s+', ' ').Trim()
    if ($Note.Length -gt 200) { $Note = $Note.Substring(0, 200) }
    # size is checked before anything is written
    $bytes = $null
    if ($PSBoundParameters.ContainsKey('Text')) { }
    elseif ($SourcePath) {
        if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) { throw "File not found: $SourcePath" }
        if ((Get-Item -LiteralPath $SourcePath).Length -gt $script:MaxFileBytes) { throw "$name is larger than 50 MB." }
    } elseif ($Base64) {
        $bytes = [Convert]::FromBase64String($Base64)
        if ($bytes.Length -gt $script:MaxFileBytes) { throw "$name is larger than 50 MB." }
    } else { throw 'Nothing to save (no content).' }
    $follows = ''
    if ($VersionOf) {
        # the family keeps its name whatever the new file is called; the extension comes from the new file
        $fk = ([IO.Path]::GetFileName($VersionOf.Trim()) -replace '[\\/:*?"<>|]', '_').Trim()
        $fam = @(Get-SnDirFamilies $dir | Where-Object { $_.family -ieq $fk })
        if (-not $fam.Count) { throw "There is no file '$fk' in this folder to add a version to." }
        $name = '{0}_v{1}{2}' -f $fam[0].family, ($fam[0].version + 1), [IO.Path]::GetExtension($name)
        $follows = Join-Path $dir $fam[0].latest
    }
    New-Item -ItemType Directory -Force -Path $dir | Out-Null

    if (-not $VersionOf -and $AddPrefix -and -not $name.StartsWith("$($t.id)_", [StringComparison]::OrdinalIgnoreCase)) {
        $rx = '^' + [regex]::Escape($t.id) + '_(\d+)_'
        $max = 0
        foreach ($f in Get-ChildItem -Path $dir -File) { if ($f.Name -match $rx) { $max = [Math]::Max($max, [int]$Matches[1]) } }
        $name = '{0}_{1:D2}_{2}' -f $t.id, ($max + 1), $name
    }
    # a versioned place shows the version from the first file on: x.sql -> x_v1.sql
    if (-not $VersionOf -and $d.Versioned -and [IO.Path]::GetFileNameWithoutExtension($name) -notmatch '_[vV]\d{1,3}$') {
        $name = '{0}_v1{1}' -f [IO.Path]::GetFileNameWithoutExtension($name), [IO.Path]::GetExtension($name)
    }
    $path = Join-Path $dir $name
    if ($AsNew -and (Test-Path -LiteralPath $path)) { throw "A file named '$name' is already here: save it as a new version or change the name." }
    $stem = [IO.Path]::GetFileNameWithoutExtension($name); $ext = [IO.Path]::GetExtension($name)
    if ($VersionOf -or $d.Versioned) {
        # never overwrite: the next free version number of the same family
        $fx = Get-SnFileFamily $name; $v = $fx.version
        while (Test-Path -LiteralPath $path) { $v++; $path = Join-Path $dir ('{0}_v{1}{2}' -f $fx.family, $v, $ext) }
    } else {
        $v = 2
        while (Test-Path -LiteralPath $path) { $path = Join-Path $dir ('{0}_v{1}{2}' -f $stem, $v, $ext); $v++ }
    }

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
    } elseif ($SourcePath) {
        [IO.File]::Copy((Get-Item -LiteralPath $SourcePath).FullName, $path)
    } else {
        [IO.File]::WriteAllBytes($path, $bytes)
    }

    # Record it on the task
    $now = Get-Now
    $rel = $path.Substring([IO.Path]::GetFullPath((Get-SnConfig).root).TrimEnd('\').Length).TrimStart('\')
    if (-not ($t.PSObject.Properties.Name -contains 'files')) { $t | Add-Member -NotePropertyName 'files' -NotePropertyValue @() }
    $rec = [ordered]@{ at = $now; path = $rel; target = $targetName }
    if ($Attachment) { $rec.question = $Question; $rec.original = [IO.Path]::GetFileName($FileName.Trim()) }
    $ff = Get-SnFileFamily ([IO.Path]::GetFileName($path))
    $rec.family = $ff.family; $rec.version = $ff.version
    $rootLen = [IO.Path]::GetFullPath((Get-SnConfig).root).TrimEnd('\').Length
    if ($follows) { $rec.follows = $follows.Substring($rootLen).TrimStart('\') }
    if ($Note) { $rec.note = $Note }
    $t.files = @($t.files) + [pscustomobject]$rec
    $t.updated = $now
    $t.history = @($t.history) + [pscustomobject]@{ at = $now; phase = $t.phase; percent = $t.percent; note = "Saved file: $rel" }
    Save-SnTask $t
    $extra = ''
    if ($follows) { $extra += " | version $($ff.version) of $($ff.family)" }
    if ($Note) { $extra += " | $Note" }
    Add-NotesLog $t "$now | FILE | $rel  ($targetName)$extra"
    if (-not $NoRefresh) { Update-SnDashboard | Out-Null }
    return [pscustomobject]@{ path = $path; relative = $rel; family = $ff.family; version = $ff.version }
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
    # attachDir: the attachments place relative to the task folder, so the page can group attachments (spec 004)
    $attachDir = (Resolve-SnAttachDir $t '').Substring($t._path.Length).TrimStart('\')
    return [pscustomobject]@{ ticket = $inTicket; elsewhere = $elsewhere; attachDir = $attachDir }
}

function Get-SnTaskImage {
    <# An image inside a task folder (01_Tickets / 99_Archive), for previews on the task page.
       Returns { path, type }; throws for anything else (other folders, other file types, missing files). #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    if ([IO.Path]::IsPathRooted($Path)) { throw 'Path must be relative to the work folder.' }
    $root = [IO.Path]::GetFullPath((Get-SnConfig).root).TrimEnd('\')
    $full = Assert-UnderRoot (Join-Path $root $Path)
    $rel = $full.Substring($root.Length).TrimStart('\')
    if ($rel -notmatch '^(01_Tickets|99_Archive)\\') { throw 'Only files in task folders can be previewed.' }
    $types = @{ '.png' = 'image/png'; '.jpg' = 'image/jpeg'; '.jpeg' = 'image/jpeg'; '.gif' = 'image/gif'; '.webp' = 'image/webp' }
    $ext = [IO.Path]::GetExtension($full).ToLower()
    if (-not $types.ContainsKey($ext)) { throw 'Only images can be previewed.' }
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "Not found: $rel" }
    return [pscustomobject]@{ path = $full; type = $types[$ext] }
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
    $tq = @{}; $tobj = @{}; $tl = @{}
    foreach ($t in $s.types) {
        $tq[$t.name] = @($t.questions | Where-Object { $_ } | ForEach-Object {
            $o = [ordered]@{ k = $_.k; q = $_.q; d = [string]$_.d }
            # intake fields (spec 004) only when the pack sets them, so plain questions look as before
            foreach ($f in 'kind', 'options', 'required', 'when', 'askIfBlank', 'sub') { if ($null -ne $_.$f) { $o[$f] = $_.$f } }
            [pscustomobject]$o })
        $tobj[$t.name] = (@($t.objects | Where-Object { $_ }).Count -gt 0)
        # the type's layout, resolved (spec 005): the page indexes save places per task from this list
        $l = Get-SnTypeLayout $s $t
        $tl[$t.name] = [pscustomobject]@{ folders = @($l.folders); attachmentsPath = $l.attachmentsPath
            useBaseChecklist = $l.useBaseChecklist; useCommonQuestions = $l.useCommonQuestions
            saveTargets = @($l.saveTargets | ForEach-Object { ConvertTo-SnMetaTarget $_ }) }
    }
    return [pscustomobject]@{
        modules = @($s.modules); types = @($s.types | ForEach-Object { $_.name }); priorities = @($s.priorities)
        defaultPriority = $s.defaultPriority; phases = @(Get-PhaseNames $s); phasePct = (Get-PhasePct $s)
        typeQuestions = $tq; typeHasObjects = $tobj; prefix = $s.prefix; root = (Get-SnConfig).root
        career = $s.career
        appearance = $s.appearance
        saveTargets = @($s.saveTargets | ForEach-Object { ConvertTo-SnMetaTarget $_ })
        attachmentsPath = $(if ("$($s.attachmentsPath)") { "$($s.attachmentsPath)" } else { '{ticket}\Attachments' })
        typeLayouts = $tl
        pack = (Get-SnMetaPack)
    }
}

function ConvertTo-SnMetaTarget($T) {
    # a save place for the page; versioned only when set, so plain places look as before
    $o = [ordered]@{ name = $T.name; path = $T.path; prefix = [bool]$T.prefix }
    if ($T.versioned -eq $true) { $o.versioned = $true }
    return [pscustomobject]$o
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
    'Set-SnCard', 'Remove-SnCard', 'Set-SnCardKeep', 'Sync-SnKnowledge', 'Get-SnArabic', 'Set-SnArabic', 'Set-SnShotRequests', 'Add-SnShot', 'Remove-SnShot', 'Set-SnCardCategory', 'Test-SnQuestionReady', 'Set-SnConceptStatus', 'Set-SnLesson', 'Remove-SnLesson', 'Save-SnLessonProgress', 'Add-SnFollowup', 'Set-SnFollowupAnswer', 'Get-SnTeach', 'Get-SnPendingFollowups', 'Get-SnDailyReview', 'Save-SnReviewDay', 'Get-SnReviewStreak', 'Add-SnQuestions', 'Remove-SnQuestion', 'Submit-SnAnswer', 'Get-SnCv', 'Save-SnCv', 'Add-SnCvBullet', 'Export-SnCv', 'Get-SnLearn', 'Get-SnSuggestions', 'New-SnTask', 'Update-SnTask', 'Get-SnTask', 'Show-SnTask', 'Close-SnTask', 'Update-SnDashboard', 'Get-SnDashboardHtml', 'Start-SnMenu', 'Get-SnTaskList', 'Find-SnTask', 'Get-SnMeta', 'Get-SnConfig', 'Get-SnSettings', 'Save-SnSettings', 'Reset-SnSettings', 'Restore-SnSettingsBackup', 'Get-SnTargetFolders', 'Save-SnFile', 'Get-SnFileFamilies', 'Get-SnTaskFiles', 'Get-SnTaskImage', 'Open-SnPath'
)
