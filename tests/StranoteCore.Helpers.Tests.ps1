# Pester 3.x tests for the pattern, date and phase helpers in StranoteCore.ps1.  Run:  Invoke-Pester D:\Projects\Stranote\tests

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here '..\src\Stranote.psm1') -Force -DisableNameChecking
. (Join-Path $here 'StranoteTestHelpers.ps1')

Describe 'Expand-Pattern' {
    InModuleScope Stranote {
        It 'replaces every known token, also when it repeats' {
            Expand-Pattern '{year}-{month}-{year}' @{ year = '2026'; month = '01' } | Should Be '2026-01-2026'
        }
        It 'keeps an unknown token as it is' {
            Expand-Pattern 'INV-{no}-{unknown}' @{ no = '7' } | Should Be 'INV-7-{unknown}'
        }
        It 'returns the pattern unchanged when there are no tokens' {
            Expand-Pattern 'plain text' @{} | Should Be 'plain text'
        }
        It 'turns non-text values into text' {
            Expand-Pattern 'n={n}' @{ n = 5 } | Should Be 'n=5'
        }
    }
}

Describe 'ConvertTo-SnDate' {
    InModuleScope Stranote {
        It 'returns an empty string for blank input' {
            ConvertTo-SnDate '' | Should Be ''
            ConvertTo-SnDate '   ' | Should Be ''
        }
        It 'keeps a valid yyyy-MM-dd date' {
            ConvertTo-SnDate '2026-01-05' | Should Be '2026-01-05'
            ConvertTo-SnDate ' 2026-01-05 ' | Should Be '2026-01-05'
        }
        It 'turns +N into N days from today' {
            $today = (Get-Date).ToString('yyyy-MM-dd')
            $plus3 = (Get-Date).AddDays(3).ToString('yyyy-MM-dd')
            ConvertTo-SnDate '+0' | Should Be $today
            ConvertTo-SnDate '+3' | Should Be $plus3
        }
        It 'rejects an impossible date' {
            { ConvertTo-SnDate '2026-02-30' } | Should Throw 'must be yyyy-MM-dd'
        }
        It 'rejects text and a bare number' {
            { ConvertTo-SnDate 'abc' } | Should Throw 'must be yyyy-MM-dd'
            { ConvertTo-SnDate '3' } | Should Throw 'must be yyyy-MM-dd'
        }
    }
}

Describe 'Get-PhaseNames' {
    InModuleScope Stranote {
        $s = [pscustomobject]@{ phases = @(
            [pscustomobject]@{ name = 'Read'; percent = 40 },
            [pscustomobject]@{ name = 'Practise' },
            [pscustomobject]@{ name = 'Test'; percent = 100 }
        ) }
        It 'returns the phase names in their order' {
            @(Get-PhaseNames $s) -join ',' | Should Be 'Read,Practise,Test'
        }
        It 'returns one name for one phase' {
            @(Get-PhaseNames ([pscustomobject]@{ phases = @([pscustomobject]@{ name = 'Only' }) })) | Should Be 'Only'
        }
        It 'returns no names when there are no phases' {
            @(Get-PhaseNames ([pscustomobject]@{ phases = @() })).Count | Should Be 0
        }
    }
}

Describe 'Get-PhasePct' {
    InModuleScope Stranote {
        $s = [pscustomobject]@{ phases = @(
            [pscustomobject]@{ name = 'Read'; percent = 40 },
            [pscustomobject]@{ name = 'Start'; percent = 0 },
            [pscustomobject]@{ name = 'Practise'; percent = '' },
            [pscustomobject]@{ name = 'Review' },
            [pscustomobject]@{ name = 'Test'; percent = '70' }
        ) }
        It 'maps each phase name to its percent as a number' {
            $h = Get-PhasePct $s
            $h['Read'] | Should Be 40
            $h['Start'] | Should Be 0
            $h['Test'] | Should Be 70
        }
        It 'skips phases whose percent is blank or missing' {
            $h = Get-PhasePct $s
            $h.Count | Should Be 3
            $h.ContainsKey('Practise') | Should Be $false
            $h.ContainsKey('Review') | Should Be $false
        }
    }
}
