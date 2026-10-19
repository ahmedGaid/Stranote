# Old name kept so older launchers, scripts and Claude skills keep working. Real module: Stranote.psm1.
. (Join-Path $PSScriptRoot 'StranoteCore.ps1')
Export-ModuleMember -Function $script:SnExports -Alias $script:SnAliasNames
