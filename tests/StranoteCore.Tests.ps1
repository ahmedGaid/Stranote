# Pester 3.x tests for the pure helpers in StranoteCore.ps1.  Run:  Invoke-Pester D:\Projects\Stranote\tests

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here '..\src\Stranote.psm1') -Force -DisableNameChecking
. (Join-Path $here 'StranoteTestHelpers.ps1')

Describe 'Test-RelPath' {
    InModuleScope Stranote {
        It 'accepts plain and nested relative folders' {
            { Test-RelPath '01_Notes' 'Folder' } | Should Not Throw
            { Test-RelPath 'a\b/c' 'Folder' } | Should Not Throw
        }
        It 'rejects empty or blank names' {
            { Test-RelPath '' 'Folder' } | Should Throw 'empty folder name'
            { Test-RelPath '   ' 'Folder' } | Should Throw 'empty folder name'
        }
        It 'rejects rooted, drive, parent and wildcard paths' {
            foreach ($bad in '\abs', '/abs', 'C:\x', '..\up', 'a\..\b', 'a*b', 'a?b', 'a"b', 'a<b', 'a>b', 'a|b') {
                { Test-RelPath $bad 'Folder' } | Should Throw 'not a valid relative folder name'
            }
        }
        It 'names the field in the error' {
            { Test-RelPath '..' 'Work folder' } | Should Throw 'Work folder'
        }
    }
}

Describe 'Get-SafeName' {
    InModuleScope Stranote {
        It 'replaces runs of unsafe characters with one underscore and trims them' {
            Get-SafeName '  Hello, World!  ' | Should Be 'Hello_World'
        }
        It 'drops hyphens by default and keeps them with -KeepHyphen' {
            Get-SafeName 'T-0001 fix' | Should Be 'T_0001_fix'
            Get-SafeName 'T-0001 fix' -KeepHyphen | Should Be 'T-0001_fix'
        }
        It 'cuts to -Max and trims a trailing underscore' {
            Get-SafeName 'abcdefghij' 4 | Should Be 'abcd'
            Get-SafeName 'abcde fghij' 6 | Should Be 'abcde'
        }
        It 'returns an empty string when nothing safe is left' {
            Get-SafeName '***' | Should Be ''
        }
    }
}

Describe 'Get-ShortCode' {
    InModuleScope Stranote {
        $s = [pscustomobject]@{ stopWords = @('the', 'for'); abbreviations = [pscustomobject]@{ invoice = 'INV' } }

        It 'drops stop words and applies abbreviations' {
            Get-ShortCode $s 'The Invoice for Aging' | Should Be 'INV_AGING'
        }
        It 'shortens words longer than 5 characters to 4' {
            Get-ShortCode $s 'Payment' | Should Be 'PAYM'
        }
        It 'drops the module name and keeps at most 3 distinct parts' {
            Get-ShortCode $s 'AP aging aging check extra words' 'AP' | Should Be 'AGING_CHECK_EXTRA'
        }
        It 'returns TASK when no word is left' {
            Get-ShortCode $s 'the for' | Should Be 'TASK'
            Get-ShortCode $s '' | Should Be 'TASK'
        }
        It 'works without stopWords or abbreviations' {
            Get-ShortCode ([pscustomobject]@{}) 'Month end' | Should Be 'MONTH_END'
        }
    }
}
