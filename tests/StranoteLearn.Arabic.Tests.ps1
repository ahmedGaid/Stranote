# Pester 3.x tests for Arabic explanations, screenshots and CV export.

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here '..\src\Stranote.psm1') -Force -DisableNameChecking
. (Join-Path $here 'StranoteTestHelpers.ps1')

Describe 'Arabic explanations' {
    $root = New-SnTestEnv
    try {
        It 'returns an empty object when the explanation file is missing or blank' {
            @((Get-SnArabic).PSObject.Properties).Count | Should Be 0
            [IO.File]::WriteAllText((Join-Path $env:STRANOTE_LEARN_DIR 'explain-ar.json'), '  ')
            @((Get-SnArabic).PSObject.Properties).Count | Should Be 0
        }
        It 'keeps omitted fields and clears fields explicitly set to empty' {
            Set-SnArabic -Id 'K-1' -Text 'short' -Example 'example' -Detail 'long' | Out-Null
            Set-SnArabic -Id 'K-1' -Text '' -Detail 'updated' | Out-Null

            $entry = (Get-SnArabic).'K-1'
            $entry.text | Should Be ''
            $entry.example | Should Be 'example'
            $entry.detail | Should Be 'updated'

            Set-SnArabic -Id 'K-1' -Example '' -Detail '' | Out-Null
            (Get-SnArabic).'K-1' | Should Be $null
        }
    } finally { Remove-SnTestEnv $root }
}

Describe 'Explanation screenshots' {
    $root = New-SnTestEnv
    try {
        It 'updates an existing request without duplicating it and attaches an image' {
            Set-SnShotRequests -Id 'K-2' -Shots @(@{ title = 'Screen'; nav = 'Menu > Screen' })
            $bytes = [Text.Encoding]::UTF8.GetBytes('test image')
            $file = Add-SnShot -Id 'K-2' -Base64 ([Convert]::ToBase64String($bytes)) -Ext '.jpeg' -Index 0 -Title 'Captured screen'
            Set-SnShotRequests -Id 'K-2' -Shots @(@{ title = 'Captured screen'; nav = 'Menu > Updated screen' })

            $images = @((Get-SnArabic).'K-2'.images)
            $images.Count | Should Be 1
            $images[0].title | Should Be 'Captured screen'
            $images[0].nav | Should Be 'Menu > Updated screen'
            $images[0].file | Should Be $file
            [IO.Path]::GetExtension($file) | Should Be '.jpg'
            Test-Path (Join-Path (Join-Path $env:STRANOTE_LEARN_DIR 'img') $file) | Should Be $true
        }
        It 'rejects unsupported image formats' {
            $base64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('test image'))
            { Add-SnShot -Id 'K-3' -Base64 $base64 -Ext 'svg' } | Should Throw 'Only PNG, JPG, GIF or WEBP images.'
        }
        It 'removes a captured image but keeps its requested slot, and removes standalone images' {
            Set-SnShotRequests -Id 'K-4' -Shots @(@{ title = 'Requested'; nav = 'Menu > Requested' })
            $base64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('test image'))
            $requestedFile = Add-SnShot -Id 'K-4' -Base64 $base64 -Index 0
            Remove-SnShot -Id 'K-4' -File $requestedFile

            $images = @((Get-SnArabic).'K-4'.images)
            $images.Count | Should Be 1
            $images[0].title | Should Be 'Requested'
            $images[0].nav | Should Be 'Menu > Requested'
            $images[0].file | Should Be ''
            Test-Path (Join-Path (Join-Path $env:STRANOTE_LEARN_DIR 'img') $requestedFile) | Should Be $false

            $standaloneFile = Add-SnShot -Id 'K-4' -Base64 $base64 -Title 'Standalone'
            Remove-SnShot -Id 'K-4' -File $standaloneFile
            @((Get-SnArabic).'K-4'.images).Count | Should Be 1
            Test-Path (Join-Path (Join-Path $env:STRANOTE_LEARN_DIR 'img') $standaloneFile) | Should Be $false
        }
    } finally { Remove-SnTestEnv $root }
}

Describe 'CV export' {
    $root = New-SnTestEnv
    try {
        It 'writes both export files under the configured root and records the export time' {
            $markdown = "# CV`n`nExported skills"
            $html = '<html><body>Exported skills</body></html>'
            Save-SnCv -Cv ([pscustomobject]@{ skills = @(); dismissed = @(); bullets = @(); lastExport = '' }) | Out-Null
            $export = Export-SnCv -Markdown $markdown -Html $html

            $export.folder | Should Be (Join-Path $root '06_Admin\CV')
            Test-Path $export.markdown | Should Be $true
            Test-Path $export.word | Should Be $true
            [IO.File]::ReadAllText($export.markdown) | Should Be $markdown
            [IO.File]::ReadAllText($export.word) | Should Be $html
            $wordBytes = [IO.File]::ReadAllBytes($export.word)
            $wordBytes[0] | Should Be 239
            $wordBytes[1] | Should Be 187
            $wordBytes[2] | Should Be 191
            (Get-SnCv).lastExport | Should Not Be ''
        }
    } finally { Remove-SnTestEnv $root }
}
