# Local web server for the live Stranote dashboard (add / update / close tasks from the browser).
# Listens on localhost only. Started by D:\Work\stranote.cmd.
#   -Config <path>  use another config.json (another work root), e.g. a second install or a test copy
param([int]$Port = 8765, [switch]$NoBrowser, [string]$Config)

$Host.UI.RawUI.WindowTitle = 'Stranote server - close this window to stop'
if ($Config) { $env:STRANOTE_CONFIG = $Config }
Import-Module (Join-Path $PSScriptRoot 'Stranote.psm1') -Force -DisableNameChecking

# First start after the career-pack upgrade: move the old settings.json to profile + pack + overrides.
# Lossless (backup first, verified, rolled back on any difference). Does nothing once migrated.
try {
    $mig = Invoke-SnMigration
    if ($mig.status -eq 'migrated') { Write-Host "Upgraded to career pack '$($mig.pack)'. Backup: $($mig.backup)" -ForegroundColor Cyan }
} catch { Write-Host "Career pack upgrade skipped, nothing changed: $($_.Exception.Message)" -ForegroundColor Yellow }
$url = "http://localhost:$Port/"
$utf8 = New-Object System.Text.UTF8Encoding $false

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($url)
try { $listener.Start() }
catch {
    # Already running (or port busy): just open the browser.
    if (-not $NoBrowser) { Start-Process $url }
    return
}
Write-Host "Stranote running at $url  (close this window to stop)" -ForegroundColor Green
if (-not $NoBrowser) { Start-Process $url }

function Send($ctx, [int]$Status, [string]$Body, [string]$Type = 'application/json') {
    $bytes = $utf8.GetBytes($Body)
    $ctx.Response.StatusCode = $Status
    $ctx.Response.ContentType = "$Type; charset=utf-8"
    $ctx.Response.Headers.Add('Cache-Control', 'no-store')
    $ctx.Response.ContentLength64 = $bytes.Length
    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $ctx.Response.OutputStream.Close()
}

function ConvertTo-Hashtable($obj) {
    $h = @{}
    if ($obj) { foreach ($p in $obj.PSObject.Properties) { if ("$($p.Value)".Trim()) { $h[$p.Name] = [string]$p.Value } } }
    return $h
}

function Str($v) { if ($null -eq $v) { '' } else { ([string]$v).Trim() } }

while ($listener.IsListening) {
    try { $ctx = $listener.GetContext() } catch { break }
    $req = $ctx.Request
    $path = $req.Url.AbsolutePath.TrimEnd('/')
    try {
        if ($req.HttpMethod -eq 'GET' -and $path -like '/img/*') {
            # screenshots for explanations: only plain image files from 04_Knowledge\Stranote\img
            $name = [IO.Path]::GetFileName([Uri]::UnescapeDataString($path.Substring(5)))
            $ext = [IO.Path]::GetExtension($name).ToLower()
            $types = @{ '.png' = 'image/png'; '.jpg' = 'image/jpeg'; '.gif' = 'image/gif'; '.webp' = 'image/webp' }
            $file = Join-Path (Join-Path (Get-SnLearnDirFor (Get-SnConfig).root) 'img') $name
            if (-not $types.ContainsKey($ext) -or -not (Test-Path $file)) { Send $ctx 404 '{"error":"not found"}'; continue }
            $bytes = [IO.File]::ReadAllBytes($file)
            $ctx.Response.StatusCode = 200; $ctx.Response.ContentType = $types[$ext]
            $ctx.Response.Headers.Add('Cache-Control', 'max-age=86400')
            $ctx.Response.ContentLength64 = $bytes.Length
            $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length); $ctx.Response.OutputStream.Close()
            continue
        }
        if ($req.HttpMethod -eq 'GET') {
            switch ($path) {
                ''           { Send $ctx 200 (Get-SnDashboardHtml -Live) 'text/html' }
                '/api/tasks' { Send $ctx 200 (ConvertTo-Json -InputObject @(Get-SnTaskList -IncludeArchive) -Depth 8 -Compress) }
                '/api/settings' {
                    $cfg = Get-SnConfig
                    $o = [pscustomobject]@{
                        settings = (Get-SnSettings); root = $cfg.root
                        existingWorkFolders = @(Get-ChildItem -Path $cfg.root -Directory | ForEach-Object { $_.Name })
                        hasBackup = (Test-Path (Join-Path $PSScriptRoot 'settings.backup.json'))
                    }
                    Send $ctx 200 ($o | ConvertTo-Json -Depth 10 -Compress)
                }
                '/api/learn' {
                    try { Sync-SnKnowledge | Out-Null } catch { Write-Host "  Knowledge sync: $($_.Exception.Message)" -ForegroundColor Yellow }
                    Send $ctx 200 (Get-SnLearn | ConvertTo-Json -Depth 8 -Compress)
                }
                '/api/review' { Send $ctx 200 (Get-SnDailyReview | ConvertTo-Json -Depth 6 -Compress) }
                '/api/packs' { Send $ctx 200 (ConvertTo-Json -InputObject @(Get-SnPackList) -Depth 6 -Compress) }
                '/api/packs/requests' { Send $ctx 200 (ConvertTo-Json -InputObject @(Get-SnPackRequest -WithDraft) -Depth 8 -Compress) }
                '/api/packs/get' {
                    try { Send $ctx 200 (Get-SnPack -Id $req.QueryString['id'] | ConvertTo-Json -Depth 20 -Compress) }
                    catch { Send $ctx 404 (@{ error = $_.Exception.Message } | ConvertTo-Json -Compress) }
                }
                '/api/profile' {
                    $prof = Get-SnProfile
                    $ob = Get-SnOnboarding
                    $pk = $null; try { $pk = Get-SnActivePack } catch { }
                    Send $ctx 200 ([pscustomobject]@{ profile = $prof; onboarding = [pscustomobject]@{ state = $ob.state; step = $ob.step }; pack = $(if ($pk) { [pscustomobject]@{ id = $pk.id; name = $pk.name; version = $pk.version } } else { $null }) } | ConvertTo-Json -Depth 10 -Compress)
                }
                '/api/onboarding' {
                    # wizard data: saved answers (pre-filled from what Stranote knows) + every pack with its areas, task types and questions
                    $packs = @(Get-SnPackList | ForEach-Object { $p = Get-SnPack -Path $_.path
                            [pscustomobject]@{ id = $p.id; name = $p.name; field = $p.field; levels = @($p.levels); description = "$($p.description)"
                                categories = @($p.categories); areas = @($p.areas | ForEach-Object { [pscustomobject]@{ id = $_.id; name = $_.name; category = $_.category; taskModule = [bool]$_.taskModule } })
                                taskTypes = @($p.taskTypes | ForEach-Object { $_.name }); phases = @($p.settings.phases | ForEach-Object { $_.name })
                                onboardingQuestions = @($p.onboardingQuestions) } })
                    $ob = Get-SnOnboarding
                    Send $ctx 200 ([pscustomobject]@{ state = $ob.state; step = $ob.step; answers = $ob.answers; packs = $packs; today = (Get-Date).ToString('yyyy-MM-dd') } | ConvertTo-Json -Depth 10 -Compress)
                }
                '/api/plan' { Send $ctx 200 (Get-SnPlan | ConvertTo-Json -Depth 6 -Compress) }
                '/api/suggest' { Send $ctx 200 (Get-SnSuggestions -Id $req.QueryString['id'] | ConvertTo-Json -Depth 5 -Compress) }
                '/api/files' { Send $ctx 200 (Get-SnTaskFiles -Id $req.QueryString['id'] | ConvertTo-Json -Depth 5 -Compress) }
                '/api/targetfolders' { Send $ctx 200 (Get-SnTargetFolders -Id $req.QueryString['id'] -Target ([int]$req.QueryString['target']) | ConvertTo-Json -Depth 4 -Compress) }
                default      { Send $ctx 404 '{"error":"not found"}' }
            }
            continue
        }
        if ($req.HttpMethod -ne 'POST') { Send $ctx 405 '{"error":"method not allowed"}'; continue }
        # Custom header blocks cross-site form posts from other web pages.
        if ($req.Headers['X-EBS'] -ne '1') { Send $ctx 403 '{"error":"forbidden"}'; continue }

        $reader = New-Object System.IO.StreamReader($req.InputStream, $utf8)
        $raw = $reader.ReadToEnd(); $reader.Close()
        $b = if ($raw) { $raw | ConvertFrom-Json } else { $null }

        switch ($path) {
            '/api/new' {
                $extra = @(Str $b.extraQuestions) -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                $r = New-SnTask -NonInteractive -Id (Str $b.id) -Title (Str $b.title) -Module (Str $b.module) -Type (Str $b.type) `
                    -Priority (Str $b.priority) -Due (Str $b.due) -Requester (Str $b.requester) -Description (Str $b.description) `
                    -ShortCode (Str $b.shortCode) -Details (ConvertTo-Hashtable $b.details) -ExtraQuestions $extra
                Send $ctx 200 (ConvertTo-Json -InputObject $r -Compress)
            }
            '/api/update' {
                $p = @{ Id = (Str $b.id) }
                if (Str $b.phase)       { $p.Phase = Str $b.phase }
                if ("$($b.percent)" -match '^\d+$') { $p.Percent = [int]$b.percent }
                if (Str $b.note)        { $p.Note = Str $b.note }
                if ($b.clearBlocker)    { $p.ClearBlocker = $true } elseif (Str $b.blocker) { $p.Blocker = Str $b.blocker }
                if (@($b.check).Count -and $null -ne $b.check)     { $p.Check = @($b.check | ForEach-Object { [int]$_ }) }
                if (@($b.uncheck).Count -and $null -ne $b.uncheck) { $p.Uncheck = @($b.uncheck | ForEach-Object { [int]$_ }) }
                $ans = ConvertTo-Hashtable $b.answers; if ($ans.Count) { $p.Answers = $ans }
                if (Str $b.addQuestion) { $p.AddQuestion = Str $b.addQuestion }
                if (Str $b.due)         { $p.Due = Str $b.due }
                if (Str $b.priority)    { $p.Priority = Str $b.priority }
                if ($p.Count -eq 1)     { throw 'Nothing to update.' }
                Update-SnTask @p | Out-Null
                Send $ctx 200 '{"ok":true}'
            }
            '/api/close' {
                $note = Str $b.note; if (-not $note) { $note = 'Closed' }
                Close-SnTask -Id (Str $b.id) -Note $note | Out-Null
                Send $ctx 200 '{"ok":true}'
            }
            '/api/settings' {
                $r = Save-SnSettings -Settings $b.settings -ApplyToActiveTickets:([bool]$b.applyToActiveTickets)
                Send $ctx 200 ($r | ConvertTo-Json -Compress)
            }
            '/api/settings/reset' {
                $r = Reset-SnSettings
                Send $ctx 200 ($r | ConvertTo-Json -Compress)
            }
            '/api/settings/undo' {
                $r = Restore-SnSettingsBackup
                Send $ctx 200 ($r | ConvertTo-Json -Compress)
            }
            '/api/openroot' {
                $sub = Str $b.path
                $target = (Get-SnConfig).root
                if ($sub -and $sub -notmatch '\.\.|:') { $target = Join-Path $target $sub }
                if (-not (Test-Path $target)) { throw "Folder not found: $target" }
                Start-Process $target
                Send $ctx 200 '{"ok":true}'
            }
            '/api/savefile' {
                $p = @{ Id = (Str $b.id); Target = [int]$b.target; SubFolder = (Str $b.subFolder); FileName = (Str $b.fileName)
                        AddPrefix = [bool]$b.addPrefix; AddHeader = [bool]$b.addHeader; Purpose = (Str $b.purpose)
                        Attachment = [bool]$b.attachment; Question = (Str $b.question) }
                if ($null -ne $b.text) { $p.Text = [string]$b.text } else { $p.Base64 = [string]$b.base64 }
                $r = Save-SnFile @p
                Send $ctx 200 ($r | ConvertTo-Json -Compress)
            }
            '/api/learn/card' {
                $r = Set-SnCard -Id (Str $b.id) -TaskId (Str $b.taskId) -Topic (Str $b.topic) -Fact (Str $b.fact) -Code ([string]$b.code) -Tags @($b.tags) -Module (Str $b.module)
                Send $ctx 200 ($r | ConvertTo-Json -Depth 5 -Compress)
            }
            '/api/learn/ar' { Set-SnArabic -Id (Str $b.id) -Text ([string]$b.text) -Example ([string]$b.example) -Detail ([string]$b.detail) | Out-Null; Send $ctx 200 '{"ok":true}' }
            '/api/learn/img' {
                $name = Add-SnShot -Id (Str $b.id) -Base64 ([string]$b.base64) -Ext (Str $b.ext) -Index ([int]$b.index) -Title (Str $b.title)
                Send $ctx 200 (ConvertTo-Json -InputObject @{ file = $name } -Compress)
            }
            '/api/learn/img/delete' { Remove-SnShot -Id (Str $b.id) -File (Str $b.file); Send $ctx 200 '{"ok":true}' }
            '/api/learn/card/category' { $r = Set-SnCardCategory -Id (Str $b.id) -Category (Str $b.category); Send $ctx 200 (ConvertTo-Json -InputObject @{ category = $r } -Compress) }
            '/api/learn/card' {
                $r = Set-SnCard -Id (Str $b.id) -TaskId (Str $b.taskId) -Topic (Str $b.topic) -Fact (Str $b.fact) -Code ([string]$b.code) -Tags @($b.tags) -Module (Str $b.module) -Category (Str $b.category)
                Send $ctx 200 ($r | ConvertTo-Json -Depth 5 -Compress)
            }
            '/api/teach/concept' {
                Set-SnConceptStatus -Keys @($b.keys | ForEach-Object { [string]$_ }) -Status (Str $b.status) -Source (Str $b.source)
                Send $ctx 200 '{"ok":true}'
            }
            '/api/teach/progress' {
                $r = Save-SnLessonProgress -LessonId (Str $b.lessonId) -Step ([int]$b.step) -Status (Str $b.status) -Score $(if ($null -ne $b.score) { [int]$b.score } else { -1 }) -Total $(if ($null -ne $b.total) { [int]$b.total } else { -1 })
                Send $ctx 200 ($r | ConvertTo-Json -Compress)
            }
            '/api/teach/followup' {
                $r = Add-SnFollowup -Kind (Str $b.kind) -Target (Str $b.target) -Concept (Str $b.concept) -Text ([string]$b.text) -Title (Str $b.title)
                Send $ctx 200 ($r | ConvertTo-Json -Compress)
            }
            '/api/learn/card/keep' { Set-SnCardKeep -Id (Str $b.id); Send $ctx 200 '{"ok":true}' }
            '/api/learn/card/delete' { Remove-SnCard -Id (Str $b.id); Send $ctx 200 '{"ok":true}' }
            '/api/learn/question/delete' { Remove-SnQuestion -Id (Str $b.id); Send $ctx 200 '{"ok":true}' }
            '/api/learn/answer' {
                $r = Submit-SnAnswer -Id (Str $b.id) -Correct ([bool]$b.correct) -Grade (Str $b.grade) -Surprise:([bool]$b.surprise)
                Send $ctx 200 ($r | ConvertTo-Json -Depth 5 -Compress)
            }
            '/api/onboarding/save' { $r = Save-SnOnboarding -Step ([int]$b.step) -Answers $b.answers; Send $ctx 200 ($r | ConvertTo-Json -Compress) }
            '/api/packs/request' {
                $r = New-SnPackRequest -Career (Str $b.career) -Field (Str $b.field) -Level (Str $b.level) -FreeAreas $b.freeAreas -FreeTasks $b.freeTasks -Tools $b.tools
                Send $ctx 200 ($r | ConvertTo-Json -Depth 6 -Compress)
            }
            '/api/packs/accept' {
                $slug = Str $b.slug; if (-not $slug) { $slug = Str $b.requestId }
                $r = Approve-SnPackDraft -Slug $slug
                Send $ctx $(if ($r.ok) { 200 } else { 400 }) ($r | ConvertTo-Json -Depth 6 -Compress)
            }
            '/api/packs/reject' { $r = Deny-SnPackDraft -Slug (Str $b.slug); Send $ctx 200 ($r | ConvertTo-Json -Compress) }
            '/api/onboarding/restart' { $r = Restart-SnOnboarding; Send $ctx 200 ($r | ConvertTo-Json -Compress) }
            '/api/onboarding/complete' {
                $r = Complete-SnOnboarding
                # morning review at the chosen time (a test server sets STRANOTE_NO_SCHEDULE so it never touches Task Scheduler)
                $scheduled = $false
                if (-not $env:STRANOTE_NO_SCHEDULE) {
                    try { & (Join-Path $PSScriptRoot 'Start-StranoteMorning.ps1') -Install -Time $r.reviewTime | Out-Null; $scheduled = $true }
                    catch { Write-Host "  Morning task: $($_.Exception.Message)" -ForegroundColor Yellow }
                }
                $r | Add-Member -NotePropertyName scheduled -NotePropertyValue $scheduled -Force
                Send $ctx 200 ($r | ConvertTo-Json -Depth 8 -Compress)
            }
            '/api/plan/item' { $r = Set-SnPlanItem -Index ([int]$b.index) -Status (Str $b.status); Send $ctx 200 ($r | ConvertTo-Json -Compress) }
            '/api/review/done' { $r = Save-SnReviewDay -Right ([int]$b.right) -Wrong ([int]$b.wrong); Send $ctx 200 ($r | ConvertTo-Json -Depth 4 -Compress) }
            '/api/learn/cv' { $r = Save-SnCv -Cv $b.cv; Send $ctx 200 ($r | ConvertTo-Json -Depth 6 -Compress) }
            '/api/learn/cv/export' {
                $r = Export-SnCv -Markdown ([string]$b.markdown) -Html ([string]$b.html)
                Start-Process $r.folder
                Send $ctx 200 ($r | ConvertTo-Json -Compress)
            }
            '/api/openpath' {
                Open-SnPath -Path (Str $b.path) -ShowInFolder:([bool]$b.showInFolder)
                Send $ctx 200 '{"ok":true}'
            }
            '/api/open' {
                Start-Process (Find-SnTask (Str $b.id) -IncludeArchive)._path
                Send $ctx 200 '{"ok":true}'
            }
            default { Send $ctx 404 '{"error":"not found"}' }
        }
    } catch {
        $msg = $_.Exception.Message
        Write-Host "  Error: $msg" -ForegroundColor Red
        try { Send $ctx 400 (ConvertTo-Json -InputObject @{ error = $msg } -Compress) } catch { }
    }
}
