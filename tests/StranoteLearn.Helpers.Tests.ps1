# Pester 3.x tests for the small helpers in StranoteLearn.ps1 that no other test covers.  Run:  Invoke-Pester D:\Projects\Stranote\tests

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here '..\src\Stranote.psm1') -Force -DisableNameChecking

Describe 'ConvertTo-StrArray' {
    InModuleScope Stranote {
        It 'trims each item and keeps the order' {
            (ConvertTo-StrArray @(' a ', 'b ', ' c')) -join ',' | Should Be 'a,b,c'
        }
        It 'drops blank and null items' {
            @(ConvertTo-StrArray @('   ', $null, '', 'x')).Count | Should Be 1
        }
        It 'returns an empty list for null' {
            @(ConvertTo-StrArray $null).Count | Should Be 0
        }
        It 'keeps one string as a one-item list' {
            $r = @(ConvertTo-StrArray 'solo')
            $r.Count | Should Be 1
            $r[0] | Should Be 'solo'
        }
    }
}

Describe 'Get-ShortHash' {
    InModuleScope Stranote {
        It 'returns 10 lowercase hex characters' {
            Get-ShortHash 'Invoice' | Should Match '^[0-9a-f]{10}$'
        }
        It 'is the same for the same text, ignoring case' {
            Get-ShortHash 'AP Aging' | Should Be (Get-ShortHash 'ap aging')
        }
        It 'differs for different text' {
            Get-ShortHash 'a' | Should Not Be (Get-ShortHash 'b')
        }
    }
}

Describe 'New-LearnId' {
    InModuleScope Stranote {
        It 'makes the prefix, a dash and 8 hex characters' {
            New-LearnId 'K' | Should Match '^K-[0-9a-f]{8}$'
        }
        It 'makes a new id every time' {
            New-LearnId 'K' | Should Not Be (New-LearnId 'K')
        }
    }
}

Describe 'Get-Today' {
    InModuleScope Stranote {
        It 'returns the date as yyyy-MM-dd' {
            Get-Today | Should Match '^\d{4}-\d{2}-\d{2}$'
        }
    }
}
