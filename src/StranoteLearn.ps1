# StranoteLearn - knowledge cards, quiz questions (spaced repetition) and CV data for Stranote.
# Dot-sourced by StranoteCore.ps1. Data lives in <root>\04_Knowledge\Stranote as plain JSON.

$script:LeitnerDays = @{ 1 = 1; 2 = 3; 3 = 7; 4 = 21; 5 = 60 }
$script:QuestionTypes = @('mcq', 'tf', 'blank', 'open', 'flash')

function Get-SnLearnDirFor([string]$Root) {
    # installs from before the Stranote rename keep their data in 04_Knowledge\Ops until it is moved
    $new = Join-Path $Root '04_Knowledge\Stranote'; $old = Join-Path $Root '04_Knowledge\Ops'
    if (-not (Test-Path $new) -and (Test-Path $old)) { return $old }
    return $new
}

function Get-LearnDir {
    # STRANOTE_LEARN_DIR lets tests run against a throw-away folder instead of your real data
    $d = if ($env:STRANOTE_LEARN_DIR) { $env:STRANOTE_LEARN_DIR } else { Get-SnLearnDirFor (Get-SnConfig).root }
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
    return $d
}
function Get-SnLearnDir { return Get-LearnDir }   # exported name for skills (e.g. where custom packs go: <learn dir>\packs)

function Read-LearnList([string]$Name) {
    $p = Join-Path (Get-LearnDir) $Name
    if (-not (Test-Path $p)) { return @() }
    $raw = [IO.File]::ReadAllText($p)
    if (-not $raw.Trim()) { return @() }
    return @($raw | ConvertFrom-Json | ForEach-Object { $_ })
}

function Write-LearnList([string]$Name, $List) {
    $items = @($List | Where-Object { $_ })
    $json = if ($items.Count) { ConvertTo-Json -InputObject $items -Depth 8 } else { '[]' }
    Write-Utf8 (Join-Path (Get-LearnDir) $Name) $json
}

function Get-SnCv {
    $p = Join-Path (Get-LearnDir) 'cv.json'
    $cv = if (Test-Path $p) { [IO.File]::ReadAllText($p) | ConvertFrom-Json } else { [pscustomobject]@{} }
    foreach ($k in 'skills', 'dismissed', 'bullets') {
        if (-not ($cv.PSObject.Properties.Name -contains $k)) { $cv | Add-Member -NotePropertyName $k -NotePropertyValue @() }
        $cv.$k = @($cv.$k | Where-Object { $_ })
    }
    return $cv
}

function New-LearnId([string]$Prefix) { return $Prefix + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8) }
function Get-Today { (Get-Date).ToString('yyyy-MM-dd') }
function ConvertTo-StrArray($v) { return @(@($v) | ForEach-Object { "$_".Trim() } | Where-Object { $_ }) }

# ---------------------------------------------------------------------------
# Knowledge cards
# ---------------------------------------------------------------------------

function Set-SnCard {
    [CmdletBinding()]
    param([string]$Id, [string]$TaskId, [Parameter(Mandatory)][string]$Topic, [string]$Fact, [string]$Code, [string[]]$Tags, [string]$Module, [string]$Category)
    if (-not $Topic.Trim()) { throw 'A card needs a topic.' }
    $cards = Read-LearnList 'cards.json'
    $company = ''
    if ($TaskId) {
        $t = @(Get-SnTaskList -IncludeArchive | Where-Object { $_.id -ieq $TaskId })
        if ($t.Count) { $company = [string]$t[0].company; if (-not $Module) { $Module = [string]$t[0].module } }
    }
    if (-not $company) { $company = Get-CurrentCompany (Get-SnSettings) }
    $now = Get-Now
    $existing = @()
    if ($Id) { $existing = @($cards | Where-Object { $_.id -eq $Id }) }
    if ($existing.Count) {
        $c = $existing[0]
        $c.topic = $Topic.Trim(); $c.fact = "$Fact".Trim(); $c.code = "$Code"; $c.tags = (ConvertTo-StrArray $Tags); $c.module = "$Module"
        $c | Add-Member -NotePropertyName updated -NotePropertyValue $now -Force
        # editing an automatic card makes it yours: auto sync will no longer overwrite it
        $c | Add-Member -NotePropertyName source -NotePropertyValue 'manual' -Force
    } else {
        $c = [pscustomobject][ordered]@{
            id = (New-LearnId 'K'); taskId = "$TaskId".ToUpper(); company = $company; module = "$Module"
            topic = $Topic.Trim(); fact = "$Fact".Trim(); code = "$Code"; tags = (ConvertTo-StrArray $Tags); source = 'manual'; created = $now; updated = $now
        }
        $cards = @($cards) + $c
    }
    Write-LearnList 'cards.json' $cards
    if ($Category) { Set-SnCardCategory -Id $c.id -Category $Category | Out-Null }

    # Every card gets an automatic flashcard question (kept in sync with the card)
    $qs = Read-LearnList 'questions.json'
    $fq = @($qs | Where-Object { $_.cardId -eq $c.id -and $_.source -eq 'card' })
    $answer = (@($c.fact, $(if ($c.code) { "`n" + $c.code })) -join '').Trim()
    if ($fq.Count) {
        $fq[0].q = $c.topic; $fq[0].answer = $answer; $fq[0].module = $c.module; $fq[0].tags = $c.tags
    } elseif ($answer) {
        $qs = @($qs) + (New-QuestionObject -Type 'flash' -Q $c.topic -Answer $answer -Module $c.module -Tags $c.tags -TaskId $c.taskId -CardId $c.id -Source 'card')
    }
    Write-LearnList 'questions.json' $qs
    return $c
}

function Remove-SnCard {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Id)
    $card = @(Read-LearnList 'cards.json' | Where-Object { $_.id -eq $Id })
    if ($card.Count -and $card[0].source -eq 'auto') {
        # hide it for good, so the next automatic sync does not bring it back
        $hidden = @(Read-LearnList 'auto-hidden.json') + $Id
        Write-LearnList 'auto-hidden.json' @($hidden | Select-Object -Unique)
    }
    Write-LearnList 'cards.json' @(Read-LearnList 'cards.json' | Where-Object { $_.id -ne $Id })
    Write-LearnList 'questions.json' @(Read-LearnList 'questions.json' | Where-Object { $_.cardId -ne $Id })
}

function Set-SnCardKeep {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Id)
    $cards = Read-LearnList 'cards.json'
    foreach ($c in $cards) { if ($c.id -eq $Id) { $c.source = 'manual'; $c.updated = Get-Now } }
    Write-LearnList 'cards.json' $cards
}

# ---------------------------------------------------------------------------
# Automatic knowledge: extracted from every task (scripts, answers, decisions)
# ---------------------------------------------------------------------------

function Get-ShortHash([string]$s) {
    $md5 = [Security.Cryptography.MD5]::Create()
    return (($md5.ComputeHash([Text.Encoding]::UTF8.GetBytes($s.ToLower())) | Select-Object -First 5 | ForEach-Object { $_.ToString('x2') }) -join '')
}

function Get-SnExtractors {
    <# Knowledge extractors of the active career pack (before migration: the Oracle EBS pack, as the old install was EBS). #>
    $pack = Get-SnPackOrLegacy
    if (-not $pack) { return @() }
    return @($pack.extractors | Where-Object { $_ })
}

function Get-TaskCodeFacts($Task, [string]$Prefix, $Extractors) {
    # APIs (package.member) and tables found in a task's scripts, using the pack's extractor rules
    if ($null -eq $Extractors) { $Extractors = Get-SnExtractors }
    $apiEx = @($Extractors | Where-Object { $_.kind -eq 'api' }); $tabEx = @($Extractors | Where-Object { $_.kind -eq 'table' })
    $apis = @{}; $tables = @{}
    if (-not ($apiEx.Count + $tabEx.Count)) { return @{ apis = $apis; tables = $tables } }
    $exts = @(@($apiEx + $tabEx) | ForEach-Object { @($_.files) } | ForEach-Object { "$_".ToLower() } | Select-Object -Unique)
    $files = @(Get-ChildItem -Path $Task._path -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $exts -contains $_.Extension.ToLower() -and $_.Length -lt 2MB })
    $own = if ($Prefix) { "$Prefix`_".ToUpper() } else { $null }
    foreach ($f in $files) {
        $rel = $f.FullName.Substring($Task._path.Length).TrimStart('\')
        $ext = $f.Extension.ToLower()
        $lines = @(); try { $lines = [IO.File]::ReadAllLines($f.FullName) } catch { continue }
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $ln = $lines[$i]
            foreach ($e in $apiEx) {
                if (@($e.files) -notcontains $ext -or ($e.commentPattern -and $ln -match $e.commentPattern)) { continue }
                foreach ($m in [regex]::Matches($ln, $e.pattern)) {
                    $member = $m.Groups['member'].Value.ToUpper(); $pkg = $m.Groups['pkg'].Value.ToUpper()
                    if (@($e.skipMembers) -contains $member -or ($e.skipOwnPrefix -and $own -and $pkg.StartsWith($own))) { continue }
                    $k = "$pkg.$member"
                    if (-not $apis.ContainsKey($k)) {
                        $n = if ($e.snippetLines) { [int]$e.snippetLines } else { 8 }
                        $snip = @(); for ($j = $i; $j -lt [Math]::Min($lines.Count, $i + $n); $j++) { $snip += $lines[$j]; if ($e.snippetEnd -and $lines[$j] -match $e.snippetEnd) { break } }
                        $apis[$k] = @{ count = 0; file = $rel; code = (($snip -join "`n").Trim()); ex = $e }
                    }
                    $apis[$k].count++
                }
            }
            foreach ($e in $tabEx) {
                if (@($e.files) -notcontains $ext -or ($e.commentPattern -and $ln -match $e.commentPattern)) { continue }
                foreach ($m in [regex]::Matches($ln, $e.pattern)) {
                    $k = $m.Groups['key'].Value.ToUpper()
                    if (($e.excludePattern -and $k -match $e.excludePattern) -or ($e.skipOwnPrefix -and $own -and $k.StartsWith($own))) { continue }
                    $op = 'REFERENCE'
                    foreach ($o in @($e.operations.PSObject.Properties)) { if ($ln -match ("$($o.Value)".Replace('{key}', $k))) { $op = $o.Name; break } }
                    if (-not $tables.ContainsKey($k)) { $tables[$k] = @{ ops = @{}; files = @{}; code = $ln.Trim(); n = 0; ex = $e } }
                    $tables[$k].ops[$op] = 1 + [int]$tables[$k].ops[$op]; $tables[$k].files[$rel] = 1; $tables[$k].n++
                    if ($op -ne 'REFERENCE' -and $tables[$k].ops.Count -eq 1 -and $tables[$k].ops[$op] -eq 1) { $tables[$k].code = $ln.Trim() }
                }
            }
        }
    }
    # drop "tables" that are really package names seen elsewhere
    foreach ($k in @($tables.Keys)) { if (@($apis.Keys | Where-Object { $_.StartsWith("$k.") }).Count) { $tables.Remove($k) } }
    return @{ apis = $apis; tables = $tables }
}

function Get-TaskTermFacts($Task, $Extractors) {
    # words and names (drugs, standards, tools...) found in a task's work files, using the pack's `term` extractors.
    # Returns one entry per extractor: @{ ex; terms = @{ lowercase key = @{ key; count; file; context } } }
    if ($null -eq $Extractors) { $Extractors = Get-SnExtractors }
    $out = @()
    $termEx = @($Extractors | Where-Object { $_.kind -eq 'term' })
    if (-not $termEx.Count) { return ,$out }
    $exts = @($termEx | ForEach-Object { if (@($_.files).Count) { @($_.files) } else { @('.txt', '.md') } } | ForEach-Object { "$_".ToLower() } | Select-Object -Unique)
    $files = @(Get-ChildItem -Path $Task._path -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $exts -contains $_.Extension.ToLower() -and $_.Length -lt 2MB -and $_.Name -ne 'task.json' } | Sort-Object FullName)
    foreach ($e in $termEx) {
        $eExts = if (@($e.files).Count) { @(@($e.files) | ForEach-Object { "$_".ToLower() }) } else { @('.txt', '.md') }
        $terms = @{}
        foreach ($f in @($files | Where-Object { $eExts -contains $_.Extension.ToLower() })) {
            $rel = $f.FullName.Substring($Task._path.Length).TrimStart('\')
            $lines = @(); try { $lines = [IO.File]::ReadAllLines($f.FullName) } catch { continue }
            foreach ($ln in $lines) {
                if ($e.commentPattern -and $ln -match $e.commentPattern) { continue }
                foreach ($m in [regex]::Matches($ln, $e.pattern)) {
                    $key = $m.Groups['key'].Value.Trim(); if (-not $key) { continue }
                    $k = $key.ToLower()
                    if ($e.excludePattern -and $key -match $e.excludePattern) { continue }
                    if (-not $terms.ContainsKey($k)) {
                        # context = the line it was first seen on, without list/heading marks, cut around the match
                        $ctx = ($ln -replace '^\s*(?:#+|[-*+>]|\d+[.)])\s*', '').Trim()
                        if ($ctx.Length -gt 180) {
                            $at = [Math]::Max(0, $ctx.IndexOf($key, [StringComparison]::OrdinalIgnoreCase) - 60)
                            $ctx = $(if ($at -gt 0) { '...' }) + $ctx.Substring($at, [Math]::Min(170, $ctx.Length - $at)).Trim() + '...'
                        }
                        $terms[$k] = @{ key = $key; count = 0; file = $rel; context = $ctx }
                    }
                    $terms[$k].count++
                }
            }
        }
        $out += @{ ex = $e; terms = $terms }
    }
    return ,$out
}

function Get-AutoKnowledge($Task, [string]$Prefix) {
    $t = $Task
    $cards = @(); $qs = @()
    $mk = {
        param($topic, $fact, $code, $tags, $kind, $category)
        $c = [pscustomobject][ordered]@{
            id = ('A-' + (Get-ShortHash "$($t.id)|$topic")); taskId = "$($t.id)"; company = "$($t.company)"; module = "$($t.module)"
            topic = $topic; fact = "$fact".Trim(); code = "$code"; tags = @(ConvertTo-StrArray $tags); source = 'auto'; kind = $kind
            created = "$($t.created)"; updated = (Get-Now)
        }
        # a pack extractor's `group` names the card category directly (Test-SnPack checks it is a category id)
        if ($category) { $c | Add-Member -NotePropertyName category -NotePropertyValue "$category" }
        $cards += $c
        Set-Variable -Name cards -Value $cards -Scope 1
    }
    $ref = "$($t.id): $($t.title)"

    # task summary
    $det = @(@($t.details) | Where-Object { $_ } | ForEach-Object { "$($_.q): $($_.a)" }) -join "`n"
    & $mk "Task: $($t.title)" ((@("$($t.description)", $det) | Where-Object { "$_".Trim() }) -join "`n") '' @($t.module, $t.type) 'task'

    # answers from the business
    foreach ($q in @(@($t.questions) | Where-Object { $_ -and $_.answered -and "$($_.answer)".Trim() })) {
        & $mk "$($q.q)" "$($q.answer)  (business answer, $ref)" '' @($t.module) 'answer'
    }

    # decisions written in _NOTES.md
    $notes = Join-Path $t._path '_NOTES.md'
    if (Test-Path $notes) {
        $inDec = $false
        foreach ($ln in [IO.File]::ReadAllLines($notes)) {
            if ($ln -match '^##\s+(.+)$') { $inDec = ($Matches[1] -match '(?i)decision|lesson|learn'); continue }
            if ($inDec -and $ln -match '^\s*[-*]\s+(.{4,})$') {
                $txt = $Matches[1].Trim()
                $short = if ($txt.Length -gt 70) { $txt.Substring(0, 67) + '...' } else { $txt }
                & $mk "Decision: $short" "$txt  ($ref)" '' @($t.module) 'decision'
            }
        }
    }

    # code: APIs and tables from the task's scripts
    $exs = Get-SnExtractors
    $code = Get-TaskCodeFacts $t $Prefix $exs
    # labels, limits and question text come from the career pack's extractors
    $apiE = @($exs | Where-Object { $_.kind -eq 'api' })[0]; $tabE = @($exs | Where-Object { $_.kind -eq 'table' })[0]
    $apiMax = if ($apiE -and $apiE.maxCards) { [int]$apiE.maxCards } else { 8 }
    $grp = if ($apiE -and $apiE.groupThreshold) { [int]$apiE.groupThreshold } else { 3 }
    $apiLabel = if ($apiE -and $apiE.label) { $apiE.label } else { 'API' }
    $tabLabel = if ($tabE -and $tabE.label) { $tabE.label } else { 'Table' }
    $tabMax = if ($tabE -and $tabE.maxCards) { [int]$tabE.maxCards } else { 6 }
    $qTpl = if ($apiE -and $apiE.question) { "$($apiE.question)" } else { 'Which package provides {members}? (you used it in {ref})' }
    $qText = { param($members) $qTpl.Replace('{members}', $members).Replace('{ref}', $ref) }
    # group by package: 1-2 procedures -> one card each, 3+ -> one card for the package
    $byPkg = @{}
    foreach ($a in $code.apis.GetEnumerator()) { $pkg = $a.Name.Split('.')[0]; if (-not $byPkg[$pkg]) { $byPkg[$pkg] = @() }; $byPkg[$pkg] += $a }
    $apiCards = 0
    foreach ($pkg in @($byPkg.Keys | Sort-Object { -(@($byPkg[$_] | ForEach-Object { $_.Value.count }) | Measure-Object -Sum).Sum }, { $_ })) {
        if ($apiCards -ge $apiMax) { break }
        $items = @($byPkg[$pkg] | Sort-Object { -$_.Value.count }, Name)
        if ($items.Count -ge $grp) {
            $procs = @($items | ForEach-Object { $_.Name.Split('.')[1] })
            $files = @($items | ForEach-Object { $_.Value.file } | Select-Object -Unique) -join ', '
            $topic = "${apiLabel}: $pkg"
            & $mk $topic "Procedures used: $($procs -join ', '). In $files for $ref." $items[0].Value.code @($t.module, $pkg) 'api'
            $qs += [pscustomobject]@{ id = ('QB-' + (Get-ShortHash "$($t.id)|$pkg")); type = 'blank'; q = (& $qText ($procs[0..([Math]::Min(2, $procs.Count - 1))] -join ', '))
                                      answer = $pkg; explain = "Also: $($procs -join ', ')."; cardId = ('A-' + (Get-ShortHash "$($t.id)|$topic")) }
            $apiCards++
        } else {
            foreach ($a in $items) {
                if ($apiCards -ge $apiMax) { break }
                $proc = $a.Name.Split('.')[1]; $topic = "${apiLabel}: $($a.Name)"
                & $mk $topic "Called $($a.Value.count) time(s) in $($a.Value.file) for $ref." $a.Value.code @($t.module, $pkg) 'api'
                $qs += [pscustomobject]@{ id = ('QB-' + (Get-ShortHash "$($t.id)|$($a.Name)")); type = 'blank'; q = (& $qText $proc); answer = $pkg
                                          explain = "Seen in $($a.Value.file)."; cardId = ('A-' + (Get-ShortHash "$($t.id)|$topic")) }
                $apiCards++
            }
        }
    }
    $topTables = @($code.tables.GetEnumerator() | Sort-Object -Property @{e = { $_.Value.n }; Descending = $true }, Name | Select-Object -First $tabMax)
    foreach ($tb in $topTables) {
        $ops = @($tb.Value.ops.GetEnumerator() | Where-Object { $_.Name -ne 'REFERENCE' } | ForEach-Object { "$($_.Name.ToLower()) x$($_.Value)" }) -join ', '
        $files = @($tb.Value.files.Keys) -join ', '
        & $mk "${tabLabel}: $($tb.Name)" ("Used in $ref" + $(if ($ops) { " ($ops)" }) + ". Files: $files.") $tb.Value.code @($t.module) 'table'
    }

    # terms: drugs, standards, tools... (pack `term` extractors; card text from cardTemplate {key} {taskId} {context})
    foreach ($tf in (Get-TaskTermFacts $t $exs)) {
        $e = $tf.ex
        $min = if ($e.minCount) { [int]$e.minCount } else { 1 }
        $max = if ($e.maxCards) { [int]$e.maxCards } else { 6 }
        $tTopic = if ($e.cardTemplate -and $e.cardTemplate.topic) { "$($e.cardTemplate.topic)" } elseif ($e.label) { "$($e.label): {key}" } else { '{key}' }
        $tFact = if ($e.cardTemplate -and $e.cardTemplate.fact) { "$($e.cardTemplate.fact)" } else { 'Seen in {taskId}: {context}' }
        $top = @($tf.terms.Values | Where-Object { $_.count -ge $min } | Sort-Object -Property @{e = { $_.count }; Descending = $true }, @{e = { $_.key } } | Select-Object -First $max)
        foreach ($x in $top) {
            $fill = { param($s) $s.Replace('{key}', $x.key).Replace('{taskId}', "$($t.id)").Replace('{context}', $x.context) }
            $topic = & $fill $tTopic
            if (@($cards | Where-Object { $_.topic -eq $topic }).Count) { continue }   # same term from two extractors
            $src = if ($tFact.Contains('{taskId}')) { $x.file } else { "$ref; $($x.file)" }
            & $mk $topic ((& $fill $tFact) + "  ($src)") '' @($t.module, $e.group) 'term' $e.group
        }
    }
    return @{ cards = $cards; questions = $qs }
}

function Sync-SnKnowledge {
    <# Rebuilds the automatic cards and questions for every task. Never touches cards you added or kept. #>
    [CmdletBinding()]
    param()
    $s = Get-SnSettings
    $cards = @(Read-LearnList 'cards.json')
    $qs = @(Read-LearnList 'questions.json')
    $hidden = @(Read-LearnList 'auto-hidden.json')
    $mine = @($cards | Where-Object { $_.source -ne 'auto' })
    $mineIds = @($mine | ForEach-Object { $_.id })
    $mineTopics = @($mine | ForEach-Object { "$($_.taskId)|$($_.topic)".ToLower() })

    $autoCards = @(); $autoQs = @()
    foreach ($t in Get-SnTaskList -IncludeArchive) {
        $k = Get-AutoKnowledge $t $s.prefix
        foreach ($c in $k.cards) {
            if ($hidden -contains $c.id -or $mineIds -contains $c.id -or $mineTopics -contains "$($c.taskId)|$($c.topic)".ToLower()) { continue }
            if (-not $c.fact -and -not $c.code) { continue }
            $old = @($cards | Where-Object { $_.id -eq $c.id }); if ($old.Count) { $c.created = $old[0].created; $c.updated = $old[0].updated }
            $autoCards += $c
            if ($c.kind -ne 'task') {
                $ans = (@($c.fact, $(if ($c.code) { "`n" + $c.code })) -join '').Trim()
                $autoQs += [pscustomobject]@{ id = ('QF-' + $c.id.Substring(2)); type = 'flash'; q = $c.topic; answer = $ans; explain = ''; cardId = $c.id; module = $c.module; tags = $c.tags; taskId = $c.taskId }
            }
        }
        $keptCardIds = @($autoCards | ForEach-Object { $_.id })
        foreach ($q in $k.questions) { if ($keptCardIds -contains $q.cardId) { $q | Add-Member -NotePropertyName module -NotePropertyValue $t.module -Force; $q | Add-Member -NotePropertyName tags -NotePropertyValue @($t.module) -Force; $q | Add-Member -NotePropertyName taskId -NotePropertyValue $t.id -Force; $autoQs += $q } }
    }

    # merge questions, keeping your spaced-repetition progress on automatic ones
    $newQs = @($qs | Where-Object { $_.source -ne 'auto' })
    $fresh = 0
    foreach ($a in $autoQs) {
        $old = @($qs | Where-Object { $_.id -eq $a.id })
        if ($old.Count) {
            $o = $old[0]; $o.q = $a.q; $o.answer = $a.answer; $o.explain = $a.explain; $o.module = $a.module; $o.tags = @(ConvertTo-StrArray $a.tags); $o.cardId = $a.cardId
            $newQs += $o
        } else {
            $n = New-QuestionObject -Type $a.type -Q $a.q -Answer $a.answer -Explain $a.explain -Module $a.module -Tags $a.tags -TaskId $a.taskId -CardId $a.cardId -Source 'auto'
            $n.id = $a.id
            # spread brand-new automatic questions: about 10 per day
            $n.due = (Get-Date).AddDays([Math]::Floor($fresh / 10)).ToString('yyyy-MM-dd'); $fresh++
            $newQs += $n
        }
    }
    $newCards = @($mine) + $autoCards
    $before = (ConvertTo-Json -InputObject @($cards) -Depth 8 -Compress) + (ConvertTo-Json -InputObject @($qs) -Depth 8 -Compress)
    $after = (ConvertTo-Json -InputObject @($newCards) -Depth 8 -Compress) + (ConvertTo-Json -InputObject @($newQs) -Depth 8 -Compress)
    if ($before -ne $after) {
        Write-LearnList 'cards.json' $newCards
        Write-LearnList 'questions.json' $newQs
    }
    return [pscustomobject]@{ autoCards = $autoCards.Count; autoQuestions = $autoQs.Count; yourCards = $mine.Count }
}

# ---------------------------------------------------------------------------
# Questions + spaced repetition (Leitner boxes 1-5: 1, 3, 7, 21, 60 days)
# ---------------------------------------------------------------------------

function New-QuestionObject {
    param([string]$Type, [string]$Q, $Options, $Answer, [string]$Explain, [string]$Module, $Tags, [string]$TaskId, [string]$CardId, [string]$Source = 'claude')
    return [pscustomobject][ordered]@{
        id = (New-LearnId 'Q'); type = $Type; q = $Q; options = @(ConvertTo-StrArray $Options); answer = $Answer; explain = "$Explain"
        module = "$Module"; tags = @(ConvertTo-StrArray $Tags); taskId = "$TaskId".ToUpper(); cardId = "$CardId"; source = $Source
        box = 1; due = (Get-Today); seen = 0; correct = 0; wrong = 0; lastAt = ''; created = (Get-Now)
    }
}

function Add-SnQuestions {
    <#
      Questions: array of hashtables/objects with
        type    mcq | tf | blank | open | flash
        q       question text
        options (mcq only) 3-5 strings
        answer  mcq: index (0-based) of the right option; tf: $true/$false; blank/open/flash: text
        explain short explanation shown after answering
        module, tags, taskId (optional)
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Questions, [string]$TaskId, [string]$Module)
    $qs = Read-LearnList 'questions.json'
    $added = @(); $pendingAr = @()
    foreach ($x in @($Questions)) {
        $get = { param($k) if ($x -is [hashtable]) { $x[$k] } else { $x.$k } }
        $type = "$(& $get 'type')".ToLower()
        if ($script:QuestionTypes -notcontains $type) { throw "Question type '$type' must be one of: $($script:QuestionTypes -join ', ')" }
        $q = "$(& $get 'q')".Trim(); if (-not $q) { throw 'A question has no text.' }
        $ans = & $get 'answer'
        $opts = @(ConvertTo-StrArray (& $get 'options'))
        if ($type -eq 'mcq') {
            if ($opts.Count -lt 2) { throw "MCQ '$q' needs at least 2 options." }
            if ($ans -isnot [int] -and "$ans" -match '^\d+$') { $ans = [int]"$ans" }
            if ($ans -isnot [int] -or $ans -lt 0 -or $ans -ge $opts.Count) { throw "MCQ '$q': answer must be the 0-based index of the right option." }
        } elseif ($type -eq 'tf') {
            $ans = [bool]("$ans" -match '^(true|1|yes)$')
        } else {
            $ans = "$ans".Trim(); if (-not $ans) { throw "Question '$q' has no answer." }
        }
        $mod = "$(& $get 'module')"; if (-not $mod) { $mod = $Module }
        $tid = "$(& $get 'taskId')"; if (-not $tid) { $tid = $TaskId }
        if ($tid -and -not $mod) { $t = @(Get-SnTaskList -IncludeArchive | Where-Object { $_.id -ieq $tid }); if ($t.Count) { $mod = $t[0].module } }
        $obj = New-QuestionObject -Type $type -Q $q -Options $opts -Answer $ans -Explain "$(& $get 'explain')" -Module $mod -Tags (& $get 'tags') -TaskId $tid -CardId "$(& $get 'cardId')" -Source 'claude'
        $qs = @($qs) + $obj; $added += $obj
        $ar = & $get 'explainAr'
        if ("$ar".Trim()) { $arMap = @{}; $arMap[$obj.id] = @{ text = "$ar"; example = "$(& $get 'exampleAr')" }; $pendingAr += $arMap }
    }
    Write-LearnList 'questions.json' $qs
    foreach ($m in $pendingAr) { Set-SnArabic -Map $m | Out-Null }
    return [pscustomobject]@{ added = $added.Count; total = @($qs).Count }
}

function Remove-SnQuestion {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Id)
    Write-LearnList 'questions.json' @(Read-LearnList 'questions.json' | Where-Object { $_.id -ne $Id })
}

function Submit-SnAnswer {
    [CmdletBinding()]
    <#  Grade (optional, default from -Correct): again = forgot (box 1, back tomorrow), hard = remembered with effort
        (box stays), good = box +1, easy = box +2.  -Surprise = asked before it was due (daily review): a right answer
        keeps the schedule (no early promotion), a wrong one still brings it back tomorrow.  #>
    param([Parameter(Mandatory)][string]$Id, [bool]$Correct, [ValidateSet('', 'again', 'hard', 'good', 'easy')][string]$Grade = '', [switch]$Surprise)
    if (-not $Grade) { $Grade = if ($Correct) { 'good' } else { 'again' } }
    $Correct = $Grade -ne 'again'
    $qs = Read-LearnList 'questions.json'
    $q = @($qs | Where-Object { $_.id -eq $Id })
    if (-not $q.Count) { throw "Question $Id not found." }
    $q = $q[0]
    $q.seen = [int]$q.seen + 1
    $box = [Math]::Max(1, [int]$q.box)
    if ($Correct) { $q.correct = [int]$q.correct + 1 } else { $q.wrong = [int]$q.wrong + 1 }
    if (-not $Correct) {
        if ($box -ge 3) { $q | Add-Member -NotePropertyName lapses -NotePropertyValue ([int]$q.lapses + 1) -Force }   # forgot something it knew
        $q.box = 1; $q.due = (Get-Date).AddDays(1).ToString('yyyy-MM-dd')
    } elseif (-not ($Surprise -and "$($q.due)" -gt (Get-Today))) {
        $q.box = switch ($Grade) { 'hard' { $box } 'easy' { [Math]::Min(5, $box + 2) } default { [Math]::Min(5, $box + 1) } }
        $q.due = (Get-Date).AddDays($script:LeitnerDays[[int]$q.box]).ToString('yyyy-MM-dd')
    }
    $h = ("$($q.hist)" + $(if ($Correct) { '1' } else { '0' })); if ($h.Length -gt 12) { $h = $h.Substring($h.Length - 12) }
    $q | Add-Member -NotePropertyName hist -NotePropertyValue $h -Force
    $q.lastAt = Get-Now
    Write-LearnList 'questions.json' $qs
    return $q
}

# ---------------------------------------------------------------------------
# CV
# ---------------------------------------------------------------------------

function Save-SnCv {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Cv)
    $out = [pscustomobject][ordered]@{
        skills    = @(@($Cv.skills) | Where-Object { $_ -and "$($_.name)".Trim() } | ForEach-Object { [pscustomobject]@{ name = "$($_.name)".Trim(); group = "$($_.group)"; added = "$($_.added)" } })
        dismissed = @(@($Cv.dismissed) | Where-Object { $_ -and "$($_.name)".Trim() } | ForEach-Object { [pscustomobject]@{ name = "$($_.name)".Trim(); xp = [int]$_.xp } })
        bullets   = @(@($Cv.bullets) | Where-Object { $_ -and "$($_.text)".Trim() } | ForEach-Object {
            [pscustomobject]@{ id = $(if ($_.id) { "$($_.id)" } else { New-LearnId 'B' }); company = "$($_.company)"; taskId = "$($_.taskId)"; text = "$($_.text)".Trim(); added = $(if ($_.added) { "$($_.added)" } else { Get-Now }) } })
        lastExport = "$($Cv.lastExport)"
    }
    Write-Utf8 (Join-Path (Get-LearnDir) 'cv.json') ($out | ConvertTo-Json -Depth 6)
    return $out
}

function Add-SnCvBullet {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Text, [string]$TaskId, [string]$Company)
    $cv = Get-SnCv
    if (-not $Company -and $TaskId) { $t = @(Get-SnTaskList -IncludeArchive | Where-Object { $_.id -ieq $TaskId }); if ($t.Count) { $Company = $t[0].company } }
    if (-not $Company) { $Company = Get-CurrentCompany (Get-SnSettings) }
    $cv.bullets = @($cv.bullets) + [pscustomobject]@{ id = (New-LearnId 'B'); company = $Company; taskId = "$TaskId".ToUpper(); text = $Text.Trim(); added = (Get-Now) }
    return Save-SnCv -Cv $cv
}

function Export-SnCv {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Markdown, [Parameter(Mandatory)][string]$Html)
    $dir = Join-Path (Get-SnConfig).root '06_Admin\CV'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $stamp = Get-Today
    $md = Join-Path $dir "Stranote_CV_$stamp.md"; $doc = Join-Path $dir "Stranote_CV_$stamp.doc"
    Write-Utf8 $md $Markdown
    [IO.File]::WriteAllText($doc, $Html, (New-Object System.Text.UTF8Encoding $true))   # BOM so Word reads UTF-8
    $cv = Get-SnCv; $cv.lastExport = Get-Now; Save-SnCv -Cv $cv | Out-Null
    return [pscustomobject]@{ markdown = $md; word = $doc; folder = $dir }
}

# ---------------------------------------------------------------------------
# Everything the dashboard needs + suggestions for a task
# ---------------------------------------------------------------------------

function Get-SnArabic {
    $p = Join-Path (Get-LearnDir) 'explain-ar.json'
    if (-not (Test-Path $p)) { return [pscustomobject]@{} }
    $raw = [IO.File]::ReadAllText($p)
    if (-not $raw.Trim()) { return [pscustomobject]@{} }
    return ($raw | ConvertFrom-Json)
}

function Set-SnArabic {
    <#
      Simple Arabic explanations (Egyptian, English keywords kept) for cards and questions.
      Stored separately (explain-ar.json, keyed by card/question id) so the automatic re-scan never erases them.
      -Map  @{ '<id>' = @{ text = '...'; example = '...' } }   or   -Path to a JSON file with the same shape.
      A question without its own entry shows the explanation of its card.
    #>
    [CmdletBinding()]
    param([hashtable]$Map, [string]$Path, [string]$Id, [string]$Text, [string]$Example, [string]$Detail)
    # Fields: text (short, ببساطة), example (مثال), detail (long explanation, light Markdown:
    # ## heading, - list, 1. list, > rule to remember, | table |, ```code```, `code`, **bold**).
    # A field you leave out keeps its current value; send it as '' to clear it.
    $cur = Get-SnArabic
    $add = @{}
    if ($Path) { $j = [IO.File]::ReadAllText($Path) | ConvertFrom-Json; foreach ($p in $j.PSObject.Properties) { $add[$p.Name] = $p.Value } }
    if ($Map) { foreach ($k in $Map.Keys) { $add[$k] = $Map[$k] } }
    if ($Id) {
        $h = @{}
        if ($PSBoundParameters.ContainsKey('Text')) { $h.text = $Text }
        if ($PSBoundParameters.ContainsKey('Example')) { $h.example = $Example }
        if ($PSBoundParameters.ContainsKey('Detail')) { $h.detail = $Detail }
        $add[$Id] = $h
    }
    foreach ($k in $add.Keys) {
        $v = $add[$k]; $old = $cur.$k
        $val = @{}
        foreach ($f in 'text', 'example', 'detail') {
            $has = if ($v -is [hashtable]) { $v.ContainsKey($f) } else { $v.PSObject.Properties.Name -contains $f }
            $nv = if ($v -is [hashtable]) { $v[$f] } else { $v.$f }
            $val[$f] = if ($has) { "$nv".Trim() } elseif ($old) { "$($old.$f)" } else { '' }
        }
        $imgs = @(if ($old -and $old.images) { $old.images })
        if (-not $val.text -and -not $val.example -and -not $val.detail -and -not $imgs.Count) { $cur.PSObject.Properties.Remove($k); continue }
        $cur | Add-Member -NotePropertyName $k -NotePropertyValue ([pscustomobject]@{ text = $val.text; example = $val.example; detail = $val.detail; images = $imgs; updated = (Get-Now) }) -Force
    }
    Write-Utf8 (Join-Path (Get-LearnDir) 'explain-ar.json') ($cur | ConvertTo-Json -Depth 4)
    return @($cur.PSObject.Properties).Count
}

# ---------------------------------------------------------------------------
# Screenshots attached to a card's explanation (files in 04_Knowledge\Stranote\img)
# entry.images = @( @{ title; nav; file; added } )  - an item without file is a requested screen (empty slot)
# ---------------------------------------------------------------------------

function Get-ShotDir { $d = Join-Path (Get-LearnDir) 'img'; if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }; return $d }

function Save-ArEntryImages([string]$Id, $Images) {
    $cur = Get-SnArabic
    $e = $cur.$Id
    if (-not $e) { $e = [pscustomobject]@{ text = ''; example = ''; detail = ''; images = @(); updated = (Get-Now) }; $cur | Add-Member -NotePropertyName $Id -NotePropertyValue $e -Force }
    if ($e.PSObject.Properties.Name -contains 'images') { $e.images = @($Images) } else { $e | Add-Member -NotePropertyName images -NotePropertyValue @($Images) }
    $e.updated = Get-Now
    Write-Utf8 (Join-Path (Get-LearnDir) 'explain-ar.json') ($cur | ConvertTo-Json -Depth 6)
}

function Set-SnShotRequests {
    <# Ask for screens: -Shots @( @{ title = 'Define Security Rules'; nav = 'GL Super User > Setup > ...' } ). Existing captured images are kept. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Id, [Parameter(Mandatory)]$Shots)
    $e = (Get-SnArabic).$Id
    $imgs = @(if ($e -and $e.images) { $e.images })
    foreach ($s in @($Shots)) {
        $t = if ($s -is [hashtable]) { $s['title'] } else { $s.title }
        $n = if ($s -is [hashtable]) { $s['nav'] } else { $s.nav }
        if (@($imgs | Where-Object { $_.title -eq $t }).Count) { foreach ($i in $imgs) { if ($i.title -eq $t) { $i.nav = "$n" } } }
        else { $imgs += [pscustomobject]@{ title = "$t"; nav = "$n"; file = ''; added = '' } }
    }
    Save-ArEntryImages $Id $imgs
}

function Add-SnShot {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Id, [Parameter(Mandatory)][string]$Base64, [string]$Ext = 'png', [int]$Index = -1, [string]$Title, [string]$Nav)
    $Ext = $Ext.ToLower().TrimStart('.'); if ($Ext -eq 'jpeg') { $Ext = 'jpg' }
    if (@('png', 'jpg', 'gif', 'webp') -notcontains $Ext) { throw 'Only PNG, JPG, GIF or WEBP images.' }
    $bytes = [Convert]::FromBase64String($Base64)
    if ($bytes.Length -gt 15MB) { throw 'Image is larger than 15 MB.' }
    $safe = ($Id -replace '[^A-Za-z0-9-]', '')
    $name = '{0}_{1}.{2}' -f $safe, [DateTime]::Now.ToString('yyyyMMddHHmmssfff'), $Ext
    [IO.File]::WriteAllBytes((Join-Path (Get-ShotDir) $name), $bytes)
    $e = (Get-SnArabic).$Id
    $imgs = @(if ($e -and $e.images) { $e.images })
    if ($Index -ge 0 -and $Index -lt $imgs.Count) {
        $imgs[$Index].file = $name; $imgs[$Index].added = (Get-Now)
        if ($Title) { $imgs[$Index].title = $Title }
    } else {
        $imgs += [pscustomobject]@{ title = $(if ($Title) { $Title } else { 'Screenshot' }); nav = "$Nav"; file = $name; added = (Get-Now) }
    }
    Save-ArEntryImages $Id $imgs
    return $name
}

function Remove-SnShot {
    <# Removes the image file; a requested screen keeps its slot (empty again), an extra image is removed completely. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Id, [Parameter(Mandatory)][string]$File)
    $e = (Get-SnArabic).$Id; if (-not $e) { return }
    $imgs = @()
    foreach ($i in @($e.images)) {
        if ($i.file -eq $File) {
            $p = Join-Path (Get-ShotDir) ([IO.Path]::GetFileName($File)); if (Test-Path $p) { Remove-Item $p -Force }
            if ($i.nav) { $i.file = ''; $i.added = ''; $imgs += $i }
        } else { $imgs += $i }
    }
    Save-ArEntryImages $Id $imgs
}

# ---------------------------------------------------------------------------
# Knowledge categories: Technical / Financial / Business / SCM
# Auto rule: business answers + decisions -> Business; APIs + tables -> Technical;
# anything else by module (settings.knowledge.financialModules / scmModules), else Technical.
# Your choice (categories.json, keyed by card id) always wins and survives the automatic re-scan.
# ---------------------------------------------------------------------------

function Get-CardAutoCategory($Card, $Settings) {
    # category rules come from the career pack: by card kind first, then by area (module), then the pack default
    $k = $Settings.knowledge
    $mod = "$($Card.module)".ToUpper()
    $kind = "$($Card.kind)"
    if ($k.byKind -and $kind -and $k.byKind.PSObject.Properties[$kind]) { return "$($k.byKind.$kind)" }
    if ($k.areaCategory -and $mod -and $k.areaCategory.PSObject.Properties[$mod]) { return "$($k.areaCategory.$mod)" }
    if ($k.defaultCategory) { return "$($k.defaultCategory)" }
    # old single settings.json (before migration to a career pack)
    switch ($kind) { 'answer' { return 'Business' } 'decision' { return 'Business' } 'api' { return 'Technical' } 'table' { return 'Technical' } }
    if (@($k.financialModules) -contains $mod) { return 'Financial' }
    if (@($k.scmModules) -contains $mod) { return 'SCM' }
    return @($k.categories)[0]
}
function Get-CategoryOverrides {
    $p = Join-Path (Get-LearnDir) 'categories.json'
    if (-not (Test-Path $p)) { return [pscustomobject]@{} }
    $raw = [IO.File]::ReadAllText($p); if (-not $raw.Trim()) { return [pscustomobject]@{} }
    return ($raw | ConvertFrom-Json)
}

function Set-SnCardCategory {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Id, [Parameter(Mandatory)][string]$Category)
    $s = Get-SnSettings
    $cats = @($s.knowledge.categories)
    $match = @($cats | Where-Object { $_ -ieq $Category })
    if (-not $match.Count) { throw "Category must be one of: $($cats -join ', ')" }
    $ov = Get-CategoryOverrides
    $ov | Add-Member -NotePropertyName $Id -NotePropertyValue $match[0] -Force
    Write-Utf8 (Join-Path (Get-LearnDir) 'categories.json') ($ov | ConvertTo-Json)
    return $match[0]
}

function Get-SnLearn {
    $s = Get-SnSettings
    $ov = Get-CategoryOverrides
    $cards = @(Read-LearnList 'cards.json')
    $byId = @{}
    foreach ($c in $cards) {
        $cat = if ($ov.($c.id)) { $ov.($c.id) } elseif ("$($c.category)") { $c.category } else { Get-CardAutoCategory $c $s }
        $c | Add-Member -NotePropertyName category -NotePropertyValue $cat -Force
        $c | Add-Member -NotePropertyName categorySet -NotePropertyValue ([bool]$ov.($c.id)) -Force
        $byId[$c.id] = $cat
    }
    $qs = @(Read-LearnList 'questions.json')
    $teach = Get-SnTeach
    foreach ($q in $qs) {
        $cat = if ($q.cardId -and $byId[$q.cardId]) { $byId[$q.cardId] } elseif ($ov.($q.id)) { $ov.($q.id) } else { Get-CardAutoCategory ([pscustomobject]@{ module = $q.module; kind = '' }) $s }
        $q | Add-Member -NotePropertyName category -NotePropertyValue $cat -Force
        # teach before quiz: only questions on concepts you have learned (or already practiced) are quiz-ready
        $q | Add-Member -NotePropertyName ready -NotePropertyValue (Test-SnQuestionReady -Question $q -Statuses $teach.concepts) -Force
    }
    return [pscustomobject]@{ cards = $cards; questions = $qs; cv = (Get-SnCv); ar = (Get-SnArabic); categories = @($s.knowledge.categories); teach = $teach; today = (Get-Today) }
}

function Get-SnSuggestions {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Id)
    $t = Find-SnTask $Id -IncludeArchive
    $apis = @{}; $tables = @{}
    $texts = @()
    foreach ($d in @($t.details)) { if ($d) { $texts += "$($d.a)" } }
    $sugExt = @(@(Get-SnExtractors) | ForEach-Object { @($_.files) } | ForEach-Object { "$_".ToLower() }) + @('.json', '.xml', '.md') | Select-Object -Unique
    foreach ($f in Get-ChildItem -Path $t._path -Recurse -File -ErrorAction SilentlyContinue |
             Where-Object { $sugExt -contains $_.Extension.ToLower() -and $_.Length -lt 2MB -and $_.Name -ne 'task.json' }) {
        try { $texts += [IO.File]::ReadAllText($f.FullName) } catch { }
    }
    $all = $texts -join "`n"
    $exs = Get-SnExtractors
    foreach ($e in @($exs | Where-Object { $_.kind -eq 'api' })) {
        foreach ($m in [regex]::Matches($all, $e.pattern)) {
            $member = $m.Groups['member'].Value.ToUpper()
            if (@($e.skipMembers) -contains $member) { continue }
            $k = ($m.Groups['pkg'].Value + '.' + $member).ToUpper(); $apis[$k] = 1 + [int]$apis[$k]
        }
    }
    $pkgNames = @($apis.Keys | ForEach-Object { $_.Split('.')[0] })
    foreach ($e in @($exs | Where-Object { $_.kind -eq 'table' })) {
        foreach ($m in [regex]::Matches($all, $e.pattern)) {
            $k = $m.Groups['key'].Value.ToUpper()
            if ($pkgNames -contains $k) { continue }
            if ($e.packagePattern -and $k -match $e.packagePattern) { $apis[$k] = 1 + [int]$apis[$k]; continue }
            $tables[$k] = 1 + [int]$tables[$k]
        }
    }    $top = { param($h) @($h.GetEnumerator() | Sort-Object -Property @{e = { $_.Value }; Descending = $true }, Name | Select-Object -First 8 | ForEach-Object { $_.Name }) }
    $answered = @(@($t.questions) | Where-Object { $_ -and $_.answered } | ForEach-Object { [pscustomobject]@{ q = $_.q; a = $_.answer } })
    return [pscustomobject]@{ apis = (& $top $apis); tables = (& $top $tables); answered = $answered }
}
