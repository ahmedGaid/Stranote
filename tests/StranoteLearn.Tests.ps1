$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here '..\src\Stranote.psm1') -Force -DisableNameChecking
. (Join-Path $here 'StranoteTestHelpers.ps1')

Describe 'Knowledge cards' {
    $root = New-SnTestEnv
    try {
        It 'updates a matching card in place and makes it manual' {
            $card = [pscustomobject][ordered]@{
                id = 'K-existing'; taskId = ''; company = ''; module = ''
                topic = 'Old topic'; fact = 'Old fact'; code = ''; tags = @()
                source = 'auto'; created = '2026-01-01'
            }
            $cardsPath = Join-Path $env:STRANOTE_LEARN_DIR 'cards.json'
            [IO.File]::WriteAllText($cardsPath, (ConvertTo-Json -InputObject @($card) -Depth 5))

            $result = Set-SnCard -Id 'K-existing' -Topic 'New topic' -Fact 'New fact'
            $cards = @([IO.File]::ReadAllText($cardsPath) | ConvertFrom-Json | ForEach-Object { $_ })

            $cards.Count | Should Be 1
            $cards[0].id | Should Be 'K-existing'
            $cards[0].topic | Should Be 'New topic'
            $cards[0].fact | Should Be 'New fact'
            $cards[0].source | Should Be 'manual'
            $cards[0].updated | Should Not BeNullOrEmpty
            $result.id | Should Be 'K-existing'
        }
    } finally { Remove-SnTestEnv $root }
}
