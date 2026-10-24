# Migration of an existing Oracle EBS install (one settings.json) to a profile + career pack + overrides.
# Dot-sourced by StranoteCore.ps1. Lossless: takes a backup first, never edits tasks or learning data,
# and rolls back if the effective settings would differ from the old ones.
# Rollback by hand: delete profile.json and overrides.json in 04_Knowledge\Stranote (settings.json is left in place).

function Get-SnLearnDataFiles {
    $d = Get-LearnDir
    return @(Get-ChildItem -Path $d -File -Filter '*.json' -ErrorAction SilentlyContinue)
}

function Invoke-SnMigration {
    [CmdletBinding()]
    param([string]$LegacySettingsPath = $script:SettingsPath, [string]$PackId = 'oracle-ebs-technical', [switch]$WhatIf)
    if (Get-SnProfile) { return [pscustomobject]@{ status = 'already-migrated' } }
    if (-not (Test-Path $LegacySettingsPath)) { return [pscustomobject]@{ status = 'nothing-to-migrate' } }
    $legacy = [IO.File]::ReadAllText($LegacySettingsPath) | ConvertFrom-Json
    $pack = Get-SnPack -Id $PackId
    $companies = @(@($legacy.career.companies) | Where-Object { $_ } | ForEach-Object { "$($_.name)" })
    $learn = Get-LearnDir
    $cfg = Get-SnConfig
    $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $backup = Join-Path $cfg.root "06_Admin\Backups\ops-migration-$stamp"
    $plan = [pscustomobject]@{
        status = 'planned'; pack = $pack.id; backup = $backup
        writes = @((Join-Path $learn 'profile.json'), (Join-Path $learn 'overrides.json'))
        keeps = @($LegacySettingsPath) + @(Get-SnLearnDataFiles | ForEach-Object { $_.FullName })
    }
    if ($WhatIf) { return $plan }

    # 1. backup: old settings, config and every learning data file
    New-Item -ItemType Directory -Force -Path $backup | Out-Null
    Copy-Item $LegacySettingsPath (Join-Path $backup 'settings.json') -Force
    if (Test-Path (Get-SnConfigPath)) { Copy-Item (Get-SnConfigPath) (Join-Path $backup 'config.json') -Force }
    foreach ($f in Get-SnLearnDataFiles) { Copy-Item $f.FullName (Join-Path $backup $f.Name) -Force }

    # 2. profile (who you are) then overrides (only what you changed on top of defaults + pack)
    $now = Get-Now
    $prof = [pscustomobject][ordered]@{
        schemaVersion = 1
        language = [pscustomobject]@{ explain = 'ar-EG'; keepTermsInEnglish = $true }
        learningStyle = @('examples', 'analogies', 'short')
        roles = @([pscustomobject][ordered]@{ id = 'r1'; packId = $pack.id; level = ''; years = $null; companies = $companies })
        ratings = [pscustomobject]@{}
        goals = [pscustomobject]@{ focusAreas = @(); target = ''; dailyMinutes = 10; reviewTime = '09:00' }
        privacy = [pscustomobject]@{ localOnly = @('code', 'screenshots', 'task notes'); neverOnCv = @('client and employer names', 'ticket IDs', 'internal object names') }
        onboarding = [pscustomobject]@{ state = 'done'; step = $null; completedAt = $now; source = 'migration' }
    }
    $learnPath = { param($n) Join-Path $learn $n }
    try {
        Save-SnProfile -SnProfile $prof | Out-Null
        Save-SnOverrides -Settings $legacy | Out-Null
        # 3. verify: effective settings must equal the old ones (except 'knowledge', which the pack now owns)
        $eff = Get-SnEffectiveSettings
        $a = Copy-SnJson $legacy; $b = Copy-SnJson $eff
        $a.PSObject.Properties.Remove('knowledge'); $b.PSObject.Properties.Remove('knowledge')
        # settings the old file never had (added later, e.g. attachmentsPath) are new, not a loss
        foreach ($n in @($b.PSObject.Properties.Name)) { if (@($a.PSObject.Properties.Name) -notcontains $n) { $b.PSObject.Properties.Remove($n) } }
        $diff = Get-SnDiff $a $b
        if ($null -ne $diff) { throw "Effective settings differ after migration: $(ConvertTo-SnCanonicalJson $diff)" }
        foreach ($c in @($legacy.knowledge.categories)) { if (@($eff.knowledge.categories) -notcontains $c) { throw "Category '$c' missing after migration." } }
    } catch {
        foreach ($n in 'profile.json', 'overrides.json') { $p = & $learnPath $n; if (Test-Path $p) { Remove-Item $p -Force } }
        $bo = & $learnPath 'overrides.backup.json'; if (Test-Path $bo) { Remove-Item $bo -Force }
        Add-SnMigrationLog "FAILED, rolled back: $($_.Exception.Message)"
        throw
    }
    $ov = Get-SnOverrides
    Add-SnMigrationLog "migrated to pack '$($pack.id)' v$($pack.version); overrides: $(@($ov.PSObject.Properties.Name) -join ', '); backup: $backup"
    return [pscustomobject]@{ status = 'migrated'; pack = $pack.id; backup = $backup; overrides = @($ov.PSObject.Properties.Name) }
}

function Add-SnMigrationLog([string]$Message) {
    try { Add-Content -Path (Join-Path (Get-LearnDir) 'migrate.log') -Value ((Get-Date).ToString('yyyy-MM-dd HH:mm:ss') + '  ' + $Message) -Encoding UTF8 } catch { }
}

function Get-SnSnapshot {
    <# Hashes of every task and learning data file under a work root: used to prove a migration changed nothing. #>
    param([Parameter(Mandatory)][string]$Root, [string]$LearnDir)
    if (-not $LearnDir) { $LearnDir = Get-SnLearnDirFor $Root }
    $md5 = [Security.Cryptography.MD5]::Create()
    $h = [ordered]@{}
    $files = @()
    foreach ($d in @((Join-Path $Root '01_Tickets'), (Join-Path $Root '99_Archive'))) { if (Test-Path $d) { $files += @(Get-ChildItem $d -Recurse -File) } }
    if (Test-Path $LearnDir) { $files += @(Get-ChildItem $LearnDir -File -Filter '*.json' | Where-Object { @('profile.json', 'overrides.json', 'overrides.backup.json') -notcontains $_.Name }) }
    foreach ($f in $files) { $h[$f.FullName.Substring($Root.Length)] = [BitConverter]::ToString($md5.ComputeHash([IO.File]::ReadAllBytes($f.FullName))) }
    return $h
}

function Compare-SnSnapshot($Before, $After) {
    $diff = @()
    foreach ($k in $Before.Keys) { if (-not $After.Contains($k)) { $diff += "removed: $k" } elseif ($Before[$k] -ne $After[$k]) { $diff += "changed: $k" } }
    foreach ($k in $After.Keys) { if (-not $Before.Contains($k)) { $diff += "added: $k" } }
    return $diff
}
