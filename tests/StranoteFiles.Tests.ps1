# Pester 3.x tests for saving files on a task (Save-SnFile / Get-SnTaskFiles).
# Run:  Invoke-Pester D:\Projects\Stranote\tests
#
# IMPORTANT: keep New-SnTestEnv / New-SnTask in BeforeEach OUTSIDE InModuleScope.
# Inside InModuleScope the test helper is not in scope, so New-SnTestEnv never runs,
# the config falls back to the real install and the test writes into D:\Work.
# The guard in BeforeEach refuses to run if the config root is not under %TEMP%.

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here '..\src\Stranote.psm1') -Force -DisableNameChecking
. (Join-Path $here 'StranoteTestHelpers.ps1')

Describe 'Save-SnFile' {
    $root = $null

    BeforeEach {
        $root = New-SnTestEnv
        # safety net: these tests must never touch the live install in D:\Work
        $cfgRoot = [IO.Path]::GetFullPath((Get-SnConfig).root)
        if (-not $cfgRoot.StartsWith([IO.Path]::GetFullPath($env:TEMP), [StringComparison]::OrdinalIgnoreCase)) {
            throw "Test env is not isolated: config root is '$cfgRoot'. Refusing to write."
        }
        New-SnTask -NonInteractive -Id 'T-0001' -Title 'Pour slab level 2' -Type 'Task' | Out-Null
    }
    AfterEach { Remove-SnTestEnv $root }

    It 'saves the text in the ticket folder and returns the relative path' {
        $r = Save-SnFile -Id 'T-0001' -FileName 'notes.txt' -Text 'hello'
        [IO.Path]::GetFileName($r.path) | Should Be 'notes.txt'
        $r.relative | Should Match 'T-0001'
        $r.relative | Should Match 'notes\.txt$'
        [IO.File]::ReadAllText($r.path) | Should Be 'hello'
    }

    It 'numbers the file with the task id when -AddPrefix is used' {
        $r = Save-SnFile -Id 'T-0001' -FileName 'script.sql' -Text 'select 1' -AddPrefix
        [IO.Path]::GetFileName($r.path) | Should Match '^T-0001_01_script\.sql$'
    }

    It 'keeps counting the prefix on the next file' {
        Save-SnFile -Id 'T-0001' -FileName 'a.sql' -Text 'a' -AddPrefix | Out-Null
        $r = Save-SnFile -Id 'T-0001' -FileName 'b.sql' -Text 'b' -AddPrefix
        [IO.Path]::GetFileName($r.path) | Should Match '^T-0001_02_b\.sql$'
    }

    It 'does not number a file that already starts with the task id' {
        $r = Save-SnFile -Id 'T-0001' -FileName 'T-0001_07_x.sql' -Text 'x' -AddPrefix
        [IO.Path]::GetFileName($r.path) | Should Match '^T-0001_07_x\.sql$'
    }

    It 'adds a version suffix instead of overwriting a file with the same name' {
        $a = Save-SnFile -Id 'T-0001' -FileName 'same.sql' -Text 'first'
        $b = Save-SnFile -Id 'T-0001' -FileName 'same.sql' -Text 'second'
        [IO.Path]::GetFileName($a.path) | Should Be 'same.sql'
        [IO.Path]::GetFileName($b.path) | Should Be 'same_v2.sql'
        [IO.File]::ReadAllText($a.path) | Should Be 'first'
        [IO.File]::ReadAllText($b.path) | Should Be 'second'
    }

    It 'adds the SQL header only for a SQL-like extension' {
        $sql = Save-SnFile -Id 'T-0001' -FileName 'x.sql' -Text 'select 1' -AddHeader -Purpose 'Report'
        $txt = [IO.File]::ReadAllText($sql.path)
        $txt | Should Match '-- Ticket : T-0001'
        $txt | Should Match '-- Purpose: Report'
        $txt | Should Match 'select 1'

        $other = Save-SnFile -Id 'T-0001' -FileName 'x.txt' -Text 'plain' -AddHeader -Purpose 'Report'
        [IO.File]::ReadAllText($other.path) | Should Be 'plain'
    }

    It 'throws when the file name has nothing usable left' {
        { Save-SnFile -Id 'T-0001' -FileName '/' -Text 'x' } | Should Throw 'File name is required'
    }

    It 'throws when there is nothing to save' {
        { Save-SnFile -Id 'T-0001' -FileName 'x.txt' } | Should Throw 'Nothing to save'
    }

    It 'refuses a sub-folder that escapes the ticket folder' {
        { Save-SnFile -Id 'T-0001' -FileName 'x.txt' -Text 'x' -SubFolder '..\..\escape' } | Should Throw
    }

    It 'throws for a save destination that does not exist' {
        { Save-SnFile -Id 'T-0001' -FileName 'x.txt' -Text 'x' -Target 99 } | Should Throw 'Unknown save destination'
    }

    It 'records the saved file on the task' {
        $r = Save-SnFile -Id 'T-0001' -FileName 'kept.txt' -Text 'keep me'
        $t = @(Get-SnTaskList)[0]
        @($t.files).Count | Should Be 1
        $t.files[0].path | Should Be $r.relative
        @($t.history | Where-Object { $_.note -like 'Saved file:*' }).Count | Should Be 1
    }

    It 'lists the saved file with Get-SnTaskFiles' {
        Save-SnFile -Id 'T-0001' -FileName 'listed.sql' -Text 'body' | Out-Null
        $f = Get-SnTaskFiles -Id 'T-0001'
        $hit = @($f.ticket | Where-Object { $_.rel -like '*listed.sql' })
        $hit.Count | Should Be 1
        $hit[0].size | Should Be 4
        @($f.elsewhere).Count | Should Be 0
    }
}