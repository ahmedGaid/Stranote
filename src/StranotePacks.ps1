# Career packs, the person's profile, and effective settings.
# Dot-sourced by StranoteCore.ps1.
#   effective settings = settings.default.json (engine, career-neutral)
#                        <- pack (areas -> modules/categories, pack.settings)
#                        <- overrides.json (the person's own changes; survive pack updates)
# Spec: specs/001-career-packs-onboarding (contracts/pack-schema.md, research R1-R4)

$script:PackFields = @('schemaVersion', 'id', 'name', 'field', 'version', 'levels', 'categories', 'categoryRules', 'areas', 'taskTypes',
    'extractors', 'starterLessons', 'skillMap', 'onboardingQuestions', 'settings', 'description', 'ui')
$script:ExtractorKinds = @('api', 'table', 'term')
$script:PackCache = @{}

function Get-SnPacksDirs {
    # shipped packs: <tool>\packs (installed) or <repo>\packs (dev); custom packs: <learn dir>\packs
    # custom first, so a person's own pack wins over a shipped one with the same id
    $dirs = @()
    $custom = Join-Path (Get-LearnDir) 'packs'
    if (Test-Path $custom) { $dirs += $custom }
    if ($env:STRANOTE_PACKS_DIR) { $dirs += $env:STRANOTE_PACKS_DIR }
    foreach ($d in @((Join-Path $PSScriptRoot 'packs'), (Join-Path (Split-Path $PSScriptRoot) 'packs'))) { if (Test-Path $d) { $dirs += $d } }
    return @($dirs | Select-Object -Unique)
}

function Get-SnPackList {
    $seen = @{}; $out = @()
    foreach ($d in Get-SnPacksDirs) {
        foreach ($f in Get-ChildItem -Path $d -Filter '*.json' -File -ErrorAction SilentlyContinue) {
            if ($seen[$f.BaseName]) { continue }
            try { $p = Get-SnPack -Path $f.FullName } catch { continue }
            $seen[$f.BaseName] = $true
            $out += [pscustomobject]@{ id = $p.id; name = $p.name; field = $p.field; version = $p.version; levels = @($p.levels)
                areas = @($p.areas | ForEach-Object { [pscustomobject]@{ id = $_.id; name = $_.name; category = $_.category } }); path = $f.FullName }
        }
    }
    return $out
}

function Test-SnPack {
    <# Validates a pack (object or file). Returns { ok, errors[] } with a JSON path in every error. #>
    [CmdletBinding()]
    param([string]$Path, $Pack)
    $errors = New-Object System.Collections.ArrayList
    $err = { param($m) [void]$errors.Add($m) }
    if ($Path) {
        try { $Pack = [IO.File]::ReadAllText($Path) | ConvertFrom-Json } catch { return [pscustomobject]@{ ok = $false; errors = @("file: not valid JSON ($($_.Exception.Message))") } }
    }
    if (-not $Pack) { return [pscustomobject]@{ ok = $false; errors = @('pack: empty') } }
    foreach ($p in $Pack.PSObject.Properties) { if ($script:PackFields -notcontains $p.Name -and $p.Name -notlike 'x-*') { & $err "$($p.Name): unknown field" } }
    if ([int]$Pack.schemaVersion -ne 1) { & $err 'schemaVersion: must be 1' }
    if ("$($Pack.id)" -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') { & $err "id: '$($Pack.id)' must be kebab-case" }
    elseif ($Path -and [IO.Path]::GetFileNameWithoutExtension($Path) -ne $Pack.id) { & $err "id: '$($Pack.id)' must match the file name" }
    foreach ($k in 'name', 'field', 'version') { if (-not "$($Pack.$k)".Trim()) { & $err "${k}: required" } }

    $catIds = @(@($Pack.categories) | Where-Object { $_ } | ForEach-Object { "$($_.id)" })
    if (-not $catIds.Count) { & $err 'categories: at least one category' }
    for ($i = 0; $i -lt $catIds.Count; $i++) { if (-not $catIds[$i]) { & $err "categories[$i].id: required" } }
    if (@($catIds | Select-Object -Unique).Count -ne $catIds.Count) { & $err 'categories: duplicate id' }
    if ($Pack.categoryRules) {
        if ($Pack.categoryRules.default -and $catIds -notcontains "$($Pack.categoryRules.default)") { & $err "categoryRules.default: '$($Pack.categoryRules.default)' is not a category id" }
        foreach ($r in @($Pack.categoryRules.byKind.PSObject.Properties)) { if ($catIds -notcontains "$($r.Value)") { & $err "categoryRules.byKind.$($r.Name): '$($r.Value)' is not a category id" } }
    }

    $areas = @($Pack.areas | Where-Object { $_ })
    if (-not $areas.Count) { & $err 'areas: at least one area' }
    $aIds = @{}
    for ($i = 0; $i -lt $areas.Count; $i++) {
        $a = $areas[$i]
        if (-not "$($a.id)".Trim()) { & $err "areas[$i].id: required"; continue }
        if ($aIds[$a.id]) { & $err "areas[$i].id: duplicate '$($a.id)'" }
        $aIds[$a.id] = $true
        if ("$($a.category)" -and $catIds -notcontains "$($a.category)") { & $err "areas[$i].category: '$($a.category)' is not a category id" }
        $cids = @(@($a.concepts) | Where-Object { $_ } | ForEach-Object { "$($_.id)" })
        if (@($cids | Select-Object -Unique).Count -ne $cids.Count) { & $err "areas[$i].concepts: duplicate concept id" }
    }

    $tt = @($Pack.taskTypes | Where-Object { $_ })
    if (-not $tt.Count) { & $err 'taskTypes: at least one task type' }
    $tn = @($tt | ForEach-Object { "$($_.name)" })
    if (@($tn | Select-Object -Unique).Count -ne $tn.Count) { & $err 'taskTypes: duplicate name' }
    for ($i = 0; $i -lt $tt.Count; $i++) {
        if (-not "$($tt[$i].name)".Trim()) { & $err "taskTypes[$i].name: required" }
        foreach ($c in @($tt[$i].checklist | Where-Object { $null -ne $_ })) { if (-not "$c".Trim()) { & $err "taskTypes[$i].checklist: empty item" } }
    }

    $ex = @($Pack.extractors | Where-Object { $_ })
    $sample = ('a' * 40) + '! ' + ('select a.b_c from fnd_x_y where x = 1; ' * 1200)   # ~50 KB, starts with a classic backtracking trap
    for ($i = 0; $i -lt $ex.Count; $i++) {
        $e = $ex[$i]
        if ($script:ExtractorKinds -notcontains "$($e.kind)") { & $err "extractors[$i].kind: must be one of $($script:ExtractorKinds -join ', ')" }
        $need = if ($e.kind -eq 'api') { @('pkg', 'member') } else { @('key') }
        if ("$($e.group)" -and $catIds -notcontains "$($e.group)") { & $err "extractors[$i].group: '$($e.group)' is not a category id" }
        foreach ($pp in @('pattern', 'excludePattern', 'commentPattern', 'packagePattern', 'snippetEnd')) {
            if (-not $e.$pp) { if ($pp -eq 'pattern') { & $err "extractors[$i].pattern: required" }; continue }
            try { $rx = New-Object Text.RegularExpressions.Regex ($e.$pp), ([Text.RegularExpressions.RegexOptions]::None), ([TimeSpan]::FromMilliseconds(200)) }
            catch { & $err "extractors[$i].${pp}: invalid regex ($($_.Exception.InnerException.Message))"; continue }
            if ($pp -eq 'pattern') { foreach ($g in $need) { if ($rx.GetGroupNames() -notcontains $g) { & $err "extractors[$i].pattern: needs a (?<$g>...) group" } } }
            # walk matches with method calls (PowerShell swallows exceptions thrown by property getters like .Count);
            # a timeout arrives wrapped in MethodInvocationException, and slow-but-under-timeout patterns are caught by the total time
            $sw = [Diagnostics.Stopwatch]::StartNew(); $slow = $false
            try { $mm = $rx.Match($sample); while ($mm.Success -and $sw.ElapsedMilliseconds -lt 300) { $mm = $mm.NextMatch() } } catch { $slow = $true }
            if ($slow -or $sw.ElapsedMilliseconds -ge 250) { & $err "extractors[$i].${pp}: too slow (over 250 ms on 50 KB)" }
        }
    }
    if ($null -ne $Pack.ui -and -not (Test-SnIsObject $Pack.ui)) { & $err 'ui: must be an object' }
    foreach ($q in @($Pack.onboardingQuestions | Where-Object { $_ })) {
        if ("$($q.writesTo)" -and "$($q.writesTo)" -notmatch '^(settings|profile|pack)\.') { & $err "onboardingQuestions.$($q.id).writesTo: must start with settings., profile. or pack." }
    }
    return [pscustomobject]@{ ok = ($errors.Count -eq 0); errors = @($errors) }
}

function Get-SnPack {
    <# Loads and validates a pack by id (custom packs win over shipped ones) or by path. Throws when invalid. #>
    [CmdletBinding()]
    param([string]$Id, [string]$Path)
    if (-not $Path) {
        foreach ($d in Get-SnPacksDirs) {
            $f = Join-Path $d "$Id.json"; if (Test-Path $f) { $Path = $f; break }
        }
        if (-not $Path) { throw "Career pack '$Id' not found." }
    }
    $stamp = (Get-Item $Path).LastWriteTimeUtc.Ticks
    $hit = $script:PackCache[$Path]
    if ($hit -and $hit.stamp -eq $stamp) { return $hit.pack }
    $pack = [IO.File]::ReadAllText($Path) | ConvertFrom-Json
    $v = Test-SnPack -Pack $pack -Path $Path
    if (-not $v.ok) { throw "Career pack '$Path' is not valid:`n - $($v.errors -join "`n - ")" }
    $script:PackCache[$Path] = @{ stamp = $stamp; pack = $pack }
    return $pack
}

# ---------------------------------------------------------------------------
# Profile
# ---------------------------------------------------------------------------

function Get-SnProfile {
    $p = Join-Path (Get-LearnDir) 'profile.json'
    if (-not (Test-Path $p)) { return $null }
    return [IO.File]::ReadAllText($p) | ConvertFrom-Json
}

function Save-SnProfile {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$SnProfile)
    if ([int]$SnProfile.schemaVersion -ne 1) { throw 'Profile schemaVersion must be 1.' }
    if (-not @($SnProfile.roles | Where-Object { $_ }).Count) { throw 'Profile needs at least one role.' }
    foreach ($r in $SnProfile.roles) { Get-SnPack -Id $r.packId | Out-Null }
    Write-Utf8 (Join-Path (Get-LearnDir) 'profile.json') ($SnProfile | ConvertTo-Json -Depth 10)
    return $SnProfile
}

function Get-SnActivePack {
    $prof = Get-SnProfile
    if (-not $prof) { return $null }
    return Get-SnPack -Id (@($prof.roles)[0].packId)
}

function Get-SnPackOrLegacy {
    <# The active pack; before migration the Oracle EBS pack (the old single-settings install was EBS); else $null. #>
    $pack = Get-SnActivePack
    if (-not $pack -and (Test-Path $script:SettingsPath)) { try { $pack = Get-SnPack -Id 'oracle-ebs-technical' } catch { } }
    return $pack
}

# ---------------------------------------------------------------------------
# Merge helpers (JSON merge patch semantics: objects merge, arrays and scalars replace)
# ---------------------------------------------------------------------------

function Test-SnIsObject($v) {
    # a JSON object; in PowerShell 5.1 a JSON array can also look like a PSCustomObject, so lists are excluded first
    if ($null -eq $v -or $v -is [string] -or $v -is [Collections.IList]) { return $false }
    return ($v -is [Management.Automation.PSCustomObject]) -or ($v -is [Collections.IDictionary])
}

# NOTE: functions here return ,$x so PowerShell does not unroll arrays (a one-item list must stay a list)
function Copy-SnJson($v) { if ($null -eq $v) { return $null }; $r = ConvertTo-Json -InputObject $v -Depth 20 -Compress | ConvertFrom-Json; return ,$r }
function Merge-SnObject($Base, $Patch) {
    if (-not (Test-SnIsObject $Patch)) { return ,(Copy-SnJson $Patch) }
    $out = if (Test-SnIsObject $Base) { Copy-SnJson $Base } else { [pscustomobject]@{} }
    foreach ($p in $Patch.PSObject.Properties) {
        $cur = $out.PSObject.Properties[$p.Name]
        if ($cur -and (Test-SnIsObject $cur.Value) -and (Test-SnIsObject $p.Value)) { $val = Merge-SnObject $cur.Value $p.Value } else { $val = Copy-SnJson $p.Value }
        $out | Add-Member -NotePropertyName $p.Name -NotePropertyValue $val -Force
    }
    return $out
}

function ConvertTo-SnCanonicalJson($v) {
    # key-sorted JSON, so two objects with the same content compare equal whatever their key order
    if ($null -eq $v) { return 'null' }
    if (Test-SnIsObject $v) {
        $props = if ($v -is [Collections.IDictionary]) { @($v.Keys | Sort-Object | ForEach-Object { [pscustomobject]@{ Name = $_; Value = $v[$_] } }) } else { @($v.PSObject.Properties | Sort-Object Name) }
        return '{' + (@($props | ForEach-Object { (ConvertTo-Json -InputObject ([string]$_.Name) -Compress) + ':' + (ConvertTo-SnCanonicalJson $_.Value) }) -join ',') + '}'
    }
    if ($v -is [array] -or $v -is [Collections.IList]) { return '[' + (@($v | ForEach-Object { ConvertTo-SnCanonicalJson $_ }) -join ',') + ']' }
    return (ConvertTo-Json -InputObject $v -Compress)
}

function Get-SnDiff($Base, $Target) {
    <# The smallest patch that turns Base into Target (for keys present in Target). $null when equal. #>
    if ((ConvertTo-SnCanonicalJson $Base) -eq (ConvertTo-SnCanonicalJson $Target)) { return $null }
    if (-not ((Test-SnIsObject $Base) -and (Test-SnIsObject $Target))) { return ,(Copy-SnJson $Target) }
    $out = [pscustomobject]@{}
    foreach ($p in $Target.PSObject.Properties) {
        $b = $Base.PSObject.Properties[$p.Name]
        if ($b) { $d = Get-SnDiff $b.Value $p.Value } else { $d = Copy-SnJson $p.Value }
        if ($null -ne $d -or ($null -eq $p.Value -and (-not $b -or $null -ne $b.Value))) { $out | Add-Member -NotePropertyName $p.Name -NotePropertyValue $d }
    }
    if (-not @($out.PSObject.Properties).Count) { return $null }
    return $out
}

# ---------------------------------------------------------------------------
# Effective settings
# ---------------------------------------------------------------------------

function Get-SnEngineDefaults { return [IO.File]::ReadAllText($script:DefaultsPath) | ConvertFrom-Json }

function Get-SnPackSettings($Pack) {
    <# The settings a pack contributes: its own settings block plus modules and knowledge derived from areas. #>
    $s = if ($Pack.settings) { Copy-SnJson $Pack.settings } else { [pscustomobject]@{} }
    $mods = @(@($Pack.areas) | Where-Object { $_ -and $_.taskModule } | ForEach-Object { "$($_.id)" })
    if ($mods.Count) { $s | Add-Member -NotePropertyName modules -NotePropertyValue $mods -Force }
    if (@($Pack.taskTypes).Count) { $tt = Copy-SnJson @($Pack.taskTypes); $s | Add-Member -NotePropertyName types -NotePropertyValue $tt.psobject.BaseObject -Force }
    $areaCat = [ordered]@{}
    foreach ($a in @($Pack.areas | Where-Object { $_ -and "$($_.category)" })) { $areaCat["$($a.id)".ToUpper()] = "$($a.category)" }
    $s | Add-Member -NotePropertyName knowledge -NotePropertyValue ([pscustomobject]@{
            categories = @(@($Pack.categories) | ForEach-Object { "$($_.id)" })
            areaCategory = [pscustomobject]$areaCat
            byKind = $(if ($Pack.categoryRules -and $Pack.categoryRules.byKind) { Copy-SnJson $Pack.categoryRules.byKind } else { [pscustomobject]@{} })
            defaultCategory = $(if ($Pack.categoryRules -and $Pack.categoryRules.default) { "$($Pack.categoryRules.default)" } else { "$(@($Pack.categories)[0].id)" })
        }) -Force
    return $s
}

function Get-SnBaseSettings($Pack) {
    $d = Get-SnEngineDefaults
    if (-not $Pack) { return $d }
    $s = Merge-SnObject $d (Get-SnPackSettings $Pack)
    # the engine keeps tasks in 01_Tickets and archives in 99_Archive, whatever the pack lists
    $wf = @(@($s.workFolders) | Where-Object { $_ })
    foreach ($r in $script:RequiredWorkFolders) { if ($wf -notcontains $r) { $wf += $r } }
    $s.workFolders = $wf
    return $s
}

function Get-SnOverrides {
    $p = Join-Path (Get-LearnDir) 'overrides.json'
    if (-not (Test-Path $p)) { return [pscustomobject]@{} }
    $o = [IO.File]::ReadAllText($p) | ConvertFrom-Json
    if (-not $o) { return [pscustomobject]@{} }
    return $o
}

function Get-SnEffectiveSettings {
    $pack = Get-SnActivePack
    $s = Merge-SnObject (Get-SnBaseSettings $pack) (Get-SnOverrides)
    return $s
}

function Save-SnOverrides {
    <# Stores only what differs from engine defaults + pack ('knowledge' is pack-owned and never overridden). #>
    param([Parameter(Mandatory)]$Settings)
    $base = Get-SnBaseSettings (Get-SnActivePack)
    $diff = Get-SnDiff $base $Settings
    if ($null -eq $diff) { $diff = [pscustomobject]@{} }
    $diff.PSObject.Properties.Remove('knowledge')
    $dir = Get-LearnDir
    $p = Join-Path $dir 'overrides.json'
    if (Test-Path $p) { Copy-Item $p (Join-Path $dir 'overrides.backup.json') -Force }
    Write-Utf8 $p ($diff | ConvertTo-Json -Depth 20)
    return $diff
}

# ---------------------------------------------------------------------------
# Pack requests (US4): "My career is not listed"
#   <learn dir>\pack-requests\<slug>.json  { slug, career, field, level, freeAreas[], freeTasks[], tools[], roleId,
#                                           status: pending|drafted|accepted|rejected, draftPath, createdAt, updatedAt }
#   The pack-builder Claude skill drafts <learn dir>\packs\<slug>.json; until it is accepted the role uses 'general'.
# ---------------------------------------------------------------------------

function ConvertTo-SnFreeList($Value) {
    # free text (one per line, or comma separated) or a list -> trimmed unique items
    $raw = @(@($Value) | Where-Object { $null -ne $_ } | ForEach-Object { "$_" -split '[\r\n,;]+' })
    $out = @(); foreach ($x in $raw) { $t = $x.Trim(); if ($t.Length -gt 120) { $t = $t.Substring(0, 120) }; if ($t -and $out -notcontains $t) { $out += $t } }
    return , @($out | Select-Object -First 40)
}

function New-SnPackRequest {
    <# Saves what the person told us about a career that has no pack. Re-sending the same career updates a pending request. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Career, [string]$Field = '', [string]$Level = '', $FreeAreas, $FreeTasks, $Tools)
    $Career = $Career.Trim()
    if (-not $Career) { throw 'Write your job title first.' }
    $areas = ConvertTo-SnFreeList $FreeAreas; $tasks = ConvertTo-SnFreeList $FreeTasks
    if (-not $areas.Count -and -not $tasks.Count) { throw 'Add at least one work area or typical task.' }
    $base = ($Career.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
    if ($base.Length -gt 40) { $base = $base.Substring(0, 40).Trim('-') }
    if (-not $base) { $base = 'career-' + (Get-Date).ToString('yyyyMMddHHmm') }
    if (@(Get-SnPackList | Where-Object { $_.id -eq $base }).Count) { $base += '-custom' }   # never shadow a shipped pack
    $dir = Join-Path (Get-LearnDir) 'pack-requests'
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $slug = $base; $n = 1; $old = $null
    while ($true) {
        $p = Join-Path $dir "$slug.json"
        if (-not (Test-Path $p)) { break }
        $o = [IO.File]::ReadAllText($p) | ConvertFrom-Json
        if ("$($o.status)" -eq 'pending') { $old = $o; break }   # same career again: update it
        $n++; $slug = "$base-$n"
    }
    $prof = Get-SnProfile
    $roleId = if ($prof -and @($prof.roles).Count) { "$(@($prof.roles)[0].id)" } else { 'r1' }
    $req = [pscustomobject][ordered]@{
        slug = $slug; career = $Career; field = $Field.Trim(); level = $Level.Trim()
        freeAreas = $areas; freeTasks = $tasks; tools = (ConvertTo-SnFreeList $Tools); roleId = $roleId
        status = 'pending'; draftPath = ''; createdAt = $(if ($old) { "$($old.createdAt)" } else { Get-Now }); updatedAt = (Get-Now)
    }
    Write-Utf8 $p ($req | ConvertTo-Json -Depth 5)
    return [pscustomobject]@{ ok = $true; slug = $slug; path = $p; request = $req }
}
