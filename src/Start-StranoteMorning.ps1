# Opens Stranote on the "Daily review" page once a day (run by the "Stranote Morning Review" scheduled task:
# at log on and at the morning time). Skips if today's review is done or Stranote was already opened for it today.
#   -Force    open anyway
#   -Install  register the scheduled task   (-Time 09:00)
#   -Uninstall remove it
param([switch]$Force, [switch]$Install, [switch]$Uninstall, [string]$Time = '09:00', [int]$Port = 8765)

$taskName = 'Stranote Morning Review'
if ($Uninstall) { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue; Write-Host 'Removed.'; return }
if ($Install) {
    $ps = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $action = New-ScheduledTaskAction -Execute $ps -Argument "-NoLogo -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $user = "$env:USERDOMAIN\$env:USERNAME"
    $atLogon = New-ScheduledTaskTrigger -AtLogOn -User $user; $atLogon.Delay = 'PT1M'
    $daily = New-ScheduledTaskTrigger -Daily -At $Time
    $set = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger @($atLogon, $daily) -Settings $set -Principal $principal `
        -Description 'Opens Stranote on the Daily review page once a day (short + long memory).' -Force | Out-Null
    Write-Host "Installed: '$taskName' runs at log on and every day at $Time."
    return
}

$here = $PSScriptRoot
$root = (Get-Content (Join-Path $here 'config.json') -Raw | ConvertFrom-Json).root
$dir = Join-Path $root '04_Knowledge\Stranote'
if (-not (Test-Path $dir) -and (Test-Path (Join-Path $root '04_Knowledge\Ops'))) { $dir = Join-Path $root '04_Knowledge\Ops' }  # install not moved yet
$today = (Get-Date).ToString('yyyy-MM-dd')
$statePath = Join-Path $dir 'morning.json'
function Log([string]$m) { try { Add-Content -Path (Join-Path $dir 'morning.log') -Value ((Get-Date).ToString('yyyy-MM-dd HH:mm:ss') + '  ' + $m) -Encoding UTF8 } catch { } }
if (-not $Force) {
    # morning only: before 14:00 (a log on in the evening should not pop up a review)
    if ((Get-Date).Hour -ge 14) { Log 'skip: after 14:00'; return }
    try { $log = Get-Content (Join-Path $dir 'review-log.json') -Raw -Encoding UTF8 | ConvertFrom-Json; if ($log.days.PSObject.Properties.Name -contains $today) { Log 'skip: review already done today'; return } } catch { }
    try { if ((Get-Content $statePath -Raw | ConvertFrom-Json).lastOpened -eq $today) { Log 'skip: already opened today'; return } } catch { }
}

$url = "http://localhost:$Port/"
$err = ''
function Test-Port { try { $c = New-Object Net.Sockets.TcpClient; $ok = $c.ConnectAsync('127.0.0.1', $Port).Wait(1500) -and $c.Connected; $c.Close(); return $ok } catch { $script:err = $_.Exception.Message; return $false } }
$up = Test-Port
if (-not $up) {
    Log 'starting the Stranote server'
    Start-Process powershell -WindowStyle Minimized -ArgumentList @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$(Join-Path $here 'StranoteServer.ps1')`"", '-NoBrowser')
    for ($i = 0; $i -lt 40 -and -not $up; $i++) { Start-Sleep -Milliseconds 500; $up = Test-Port }
}
if (-not $up) { Log "server did not start: $err"; return }
Start-Process "$url#review"
Log 'opened daily review'
[IO.File]::WriteAllText($statePath, (@{ lastOpened = $today } | ConvertTo-Json), (New-Object Text.UTF8Encoding $false))
