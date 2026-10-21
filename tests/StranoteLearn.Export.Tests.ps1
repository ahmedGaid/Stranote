# Pester 3.x regression tests for Export-SnCv on first use (no cv.json yet).  Run:  Invoke-Pester D:\Projects\Stranote\tests

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here '..\src\Stranote.psm1') -Force -DisableNameChecking
. (Join-Path $here 'StranoteTestHelpers.ps1')

Describe 'Export-SnCv' {
    $root = New-SnTestEnv
    InModuleScope Stranote {
        $cvPath = Join-Path (Get-LearnDir) 'cv.json'

        It 'exports on first use when cv.json does not exist yet' {
            Test-Path $cvPath | Should Be $false
            $r = Export-SnCv -Markdown '# CV' -Html '<p>CV</p>'
            Test-Path $r.markdown | Should Be $true
            Test-Path $r.word | Should Be $true
            (Get-SnCv).lastExport | Should Not BeNullOrEmpty
        }
        It 'exports when an older cv.json has no lastExport field' {
            [IO.File]::WriteAllText($cvPath, '{"skills":[],"dismissed":[],"bullets":[]}', (New-Object Text.UTF8Encoding $false))
            { Export-SnCv -Markdown '# CV' -Html '<p>CV</p>' } | Should Not Throw
            (Get-SnCv).lastExport | Should Not BeNullOrEmpty
        }
        It 'Get-SnCv always has lastExport, empty before the first export' {
            Remove-Item $cvPath -Force
            $cv = Get-SnCv
            $cv.PSObject.Properties.Name -contains 'lastExport' | Should Be $true
            $cv.lastExport | Should Be ''
        }
    }
    Remove-SnTestEnv $root
}
