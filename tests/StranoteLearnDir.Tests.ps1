$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here '..\src\Stranote.psm1') -Force -DisableNameChecking

Describe 'Get-SnLearnDirFor' {
    InModuleScope Stranote {
        It 'returns the Stranote path when neither folder exists' {
            $root = Join-Path $env:TEMP ('stranote-learn-dir-' + [guid]::NewGuid().ToString('N'))
            try {
                Get-SnLearnDirFor $root | Should Be (Join-Path $root '04_Knowledge\Stranote')
            } finally {
                if (Test-Path $root) { Remove-Item $root -Recurse -Force }
            }
        }

        It 'uses the legacy Ops folder when Stranote does not exist' {
            $root = Join-Path $env:TEMP ('stranote-learn-dir-' + [guid]::NewGuid().ToString('N'))
            $legacy = Join-Path $root '04_Knowledge\Ops'
            try {
                New-Item -ItemType Directory -Path $legacy -Force | Out-Null
                Get-SnLearnDirFor $root | Should Be $legacy
            } finally {
                if (Test-Path $root) { Remove-Item $root -Recurse -Force }
            }
        }

        It 'prefers the Stranote folder when both folders exist' {
            $root = Join-Path $env:TEMP ('stranote-learn-dir-' + [guid]::NewGuid().ToString('N'))
            $stranote = Join-Path $root '04_Knowledge\Stranote'
            $legacy = Join-Path $root '04_Knowledge\Ops'
            try {
                New-Item -ItemType Directory -Path $stranote, $legacy -Force | Out-Null
                Get-SnLearnDirFor $root | Should Be $stranote
            } finally {
                if (Test-Path $root) { Remove-Item $root -Recurse -Force }
            }
        }
    }
}
