# Pester 3.x tests for Write-Utf8 and Get-Now in StranoteCore.ps1.  Run:  Invoke-Pester D:\Projects\Stranote\tests

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here '..\src\Stranote.psm1') -Force -DisableNameChecking
. (Join-Path $here 'StranoteTestHelpers.ps1')

Describe 'Write-Utf8' {
    InModuleScope Stranote {
        It 'creates a file with the exact text' {
            $dir = Join-Path $env:TEMP ('sn-utf8-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -ItemType Directory -Path $dir | Out-Null
            try {
                $path = Join-Path $dir 'plain.txt'
                Write-Utf8 $path "hello`nworld"
                [IO.File]::ReadAllText($path) | Should Be "hello`nworld"
            } finally {
                Remove-Item $dir -Recurse -Force
            }
        }

        It 'writes UTF-8 without a BOM' {
            $dir = Join-Path $env:TEMP ('sn-utf8-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -ItemType Directory -Path $dir | Out-Null
            try {
                $path = Join-Path $dir 'nobom.txt'
                Write-Utf8 $path 'abc'
                $bytes = [IO.File]::ReadAllBytes($path)
                $bytes.Length | Should Be 3
                $bytes[0] | Should Be 97
                $bytes[1] | Should Be 98
                $bytes[2] | Should Be 99
            } finally {
                Remove-Item $dir -Recurse -Force
            }
        }

        It 'keeps non-ASCII code points (Arabic + newline) as UTF-8' {
            # Build Arabic letters in ASCII source so the .ps1 stays ANSI-safe.
            $ar = -join @(
                [char]0x0645, [char]0x0631, [char]0x062D, [char]0x0628, [char]0x0627
            )
            $text = $ar + "`n" + 'ok'
            $dir = Join-Path $env:TEMP ('sn-utf8-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -ItemType Directory -Path $dir | Out-Null
            try {
                $path = Join-Path $dir 'ar.txt'
                Write-Utf8 $path $text
                $got = [IO.File]::ReadAllText($path, (New-Object System.Text.UTF8Encoding $false))
                $got | Should Be $text
                $bytes = [IO.File]::ReadAllBytes($path)
                # First Arabic letter U+0645 is UTF-8 D9 85; must not start with BOM EF BB BF
                $bytes[0] | Should Be 0xD9
                $bytes[1] | Should Be 0x85
            } finally {
                Remove-Item $dir -Recurse -Force
            }
        }

        It 'overwrites an existing file' {
            $dir = Join-Path $env:TEMP ('sn-utf8-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -ItemType Directory -Path $dir | Out-Null
            try {
                $path = Join-Path $dir 'ovr.txt'
                Write-Utf8 $path 'old'
                Write-Utf8 $path 'new'
                [IO.File]::ReadAllText($path) | Should Be 'new'
            } finally {
                Remove-Item $dir -Recurse -Force
            }
        }
    }
}

Describe 'Get-Now' {
    InModuleScope Stranote {
        It 'returns yyyy-MM-dd HH:mm' {
            Get-Now | Should Match '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$'
        }

        It 'matches the current minute' {
            $a = Get-Now
            $b = (Get-Date).ToString('yyyy-MM-dd HH:mm')
            $a | Should Be $b
        }
    }
}
