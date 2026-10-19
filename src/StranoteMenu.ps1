$Host.UI.RawUI.WindowTitle = 'Stranote'
Import-Module (Join-Path $PSScriptRoot 'Stranote.psm1') -Force -DisableNameChecking
Start-SnMenu
