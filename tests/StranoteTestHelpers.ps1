# Shared helpers for Stranote tests: every test runs in a throw-away copy, never on real data.

function New-SnTestEnv {
    <# Empty work root with its own config.json and learn dir. Returns the root. #>
    param([string]$Fixture)
    $root = Join-Path $env:TEMP ('ops-test-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $root | Out-Null
    if ($Fixture) { Copy-Item (Join-Path $Fixture '*') $root -Recurse -Force }
    $work = if (Test-Path (Join-Path $root 'work')) { Join-Path $root 'work' } else { $root }
    $cfg = Join-Path $root 'config.json'
    [IO.File]::WriteAllText($cfg, (([pscustomobject]@{ root = $work; prefix = 'XXCUST'; author = ''; nextAutoId = 3 }) | ConvertTo-Json), (New-Object Text.UTF8Encoding $false))
    $env:STRANOTE_CONFIG = $cfg
    $env:STRANOTE_LEARN_DIR = Join-Path $work '04_Knowledge\Stranote'
    # legacy fixtures keep their data in 04_Knowledge\Ops (installs from before the rename)
    if (Test-Path (Join-Path $work '04_Knowledge\Ops')) { $env:STRANOTE_LEARN_DIR = Join-Path $work '04_Knowledge\Ops' }
    New-Item -ItemType Directory -Force -Path $env:STRANOTE_LEARN_DIR | Out-Null
    return $root
}

function Remove-SnTestEnv([string]$Root) {
    Remove-Item Env:STRANOTE_CONFIG -ErrorAction SilentlyContinue
    Remove-Item Env:STRANOTE_LEARN_DIR -ErrorAction SilentlyContinue
    if ($Root -and (Test-Path $Root)) { Remove-Item $Root -Recurse -Force }
}
