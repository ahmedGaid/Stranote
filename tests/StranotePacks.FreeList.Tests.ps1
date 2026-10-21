# Pester 3.x tests for ConvertTo-SnFreeList in StranotePacks.ps1 (the free-text lists of a pack request).  Run:  Invoke-Pester D:\Projects\Stranote\tests

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here '..\src\Stranote.psm1') -Force -DisableNameChecking
. (Join-Path $here 'StranoteTestHelpers.ps1')

Describe 'ConvertTo-SnFreeList' {
    InModuleScope Stranote {
        It 'splits free text on new lines, commas and semicolons' {
            $items = ConvertTo-SnFreeList "bank`nledger, invoices;payroll"
            ($items -join '|') | Should Be 'bank|ledger|invoices|payroll'
        }
        It 'accepts a list as well as free text' {
            $items = ConvertTo-SnFreeList @('bank', 'ledger,invoices')
            ($items -join '|') | Should Be 'bank|ledger|invoices'
        }
        It 'trims spaces and drops empty items' {
            $items = ConvertTo-SnFreeList "  bank  ,, ,  ledger "
            ($items -join '|') | Should Be 'bank|ledger'
        }
        It 'keeps the first of repeated items' {
            $items = ConvertTo-SnFreeList 'bank, ledger, bank'
            ($items -join '|') | Should Be 'bank|ledger'
        }
        It 'treats repeats that differ only by case as the same item (PowerShell -notcontains)' {
            $items = ConvertTo-SnFreeList 'Bank, bank'
            ($items -join '|') | Should Be 'Bank'
        }
        It 'cuts each item to 120 characters' {
            $long = ConvertTo-SnFreeList ('x' * 150)
            $long.Count | Should Be 1
            $long[0].Length | Should Be 120
        }
        It 'keeps at most 40 items' {
            $many = ConvertTo-SnFreeList ((1..50) -join ',')
            $many.Count | Should Be 40
            $many[0] | Should Be '1'
            $many[39] | Should Be '40'
        }
        It 'returns an empty list for blank or missing input' {
            $items = ConvertTo-SnFreeList ''
            $items.Count | Should Be 0
            $items = ConvertTo-SnFreeList $null
            $items.Count | Should Be 0
            $items = ConvertTo-SnFreeList @()
            $items.Count | Should Be 0
        }
    }
}
