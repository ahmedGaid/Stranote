# First-day onboarding (spec 001, US2). Dot-sourced by StranoteCore.ps1 after StranotePacks.ps1.
# Data in the learn dir:
#   onboarding.json { step, answers{...}, updatedAt }   raw wizard answers (resume / re-run; pasted CV stays here only)
#   plan.json       { createdAt, from, perDay, items:[{ day, areaId, conceptId, title, minutes, status }] }
# Answers (all optional except packId):
#   language, style[], packId, level, years, ratings{areaId: new|basic|comfortable|expert},
#   company, title, start, industry, weekend[], workStart, workEnd, packAnswers{questionId: value},
#   taskTypes[], workRoot, focusAreas[], target, dailyMinutes, reviewTime, localOnly[], neverOnCv[], cvText
# Completing never registers the morning task itself; the server does that with the returned reviewTime.

$script:RatingStatus = @{ expert = 'known'; comfortable = 'understood'; basic = 'taught'; new = 'new' }
$script:StatusRank = @{ 'new' = 0; 'taught' = 1; 'needs-help' = 1; 'understood' = 2; 'known' = 3 }

function Read-SnOnboardingFile {
    $p = Join-Path (Get-LearnDir) 'onboarding.json'
    if (-not (Test-Path $p)) { return $null }
    return [IO.File]::ReadAllText($p) | ConvertFrom-Json
}

function Get-SnOnboardingDefaults {
    # what Stranote already knows (profile + settings), so a re-run or a migrated user starts pre-filled
    $prof = Get-SnProfile; $s = Get-SnSettings; $cfg = Get-SnConfig
    $role = if ($prof) { @($prof.roles)[0] } else { $null }
    $company = ''; if ($role -and @($role.companies).Count) { $company = "$(@($role.companies)[0])" }
    if (-not $company) { $company = Get-CurrentCompany $s }
    $c = @($s.career.companies | Where-Object { $_ -and $_.name -eq $company })[0]
    $ratings = [pscustomobject]@{}
    if ($prof -and $prof.ratings -and $role -and $prof.ratings.PSObject.Properties[$role.id]) { $ratings = $prof.ratings.($role.id) }
    $d = [ordered]@{
        language = $(if ($prof -and $prof.language.explain) { "$($prof.language.explain)" } else { 'en' })
        style = $(if ($prof -and $prof.learningStyle) { @($prof.learningStyle) } else { @('examples', 'short') })
        packId = $(if ($role) { "$($role.packId)" } else { '' })
        level = $(if ($role) { "$($role.level)" } else { '' }); years = $(if ($role) { $role.years } else { $null })
        ratings = $ratings
        company = $company; title = $(if ($c) { "$($c.role)" } else { '' }); start = $(if ($c) { "$($c.start)" } else { '' })
        industry = ''; weekend = @($s.career.weekend); workStart = '09:00'; workEnd = '17:00'
        packAnswers = [pscustomobject]@{ prefix = "$($s.prefix)" }
        taskTypes = @($s.types | ForEach-Object { "$($_.name)" }); workRoot = "$($cfg.root)"
        focusAreas = $(if ($prof -and $prof.goals.focusAreas) { @($prof.goals.focusAreas) } else { @() })
        target = $(if ($prof) { "$($prof.goals.target)" } else { '' })
        dailyMinutes = $(if ($prof -and $prof.goals.dailyMinutes) { [int]$prof.goals.dailyMinutes } else { 10 })
        reviewTime = $(if ($prof -and $prof.goals.reviewTime) { "$($prof.goals.reviewTime)" } else { '09:00' })
        localOnly = $(if ($prof -and $prof.privacy) { @($prof.privacy.localOnly) } else { @('code', 'screenshots', 'task notes') })
        neverOnCv = $(if ($prof -and $prof.privacy) { @($prof.privacy.neverOnCv) } else { @('client and employer names', 'ticket IDs', 'internal object names') })
    }
    if ($prof -and $prof.packAnswers) { $d.packAnswers = Merge-SnObject $d.packAnswers $prof.packAnswers }
    return [pscustomobject]$d
}

function Get-SnOnboarding {
    $prof = Get-SnProfile; $saved = Read-SnOnboardingFile
    $state = if ($prof) { $(if ("$($prof.onboarding.state)") { "$($prof.onboarding.state)" } else { 'done' }) } elseif ($saved) { 'in-progress' } else { 'required' }
    $answers = Get-SnOnboardingDefaults
    if ($saved -and $saved.answers) { $answers = Merge-SnObject $answers $saved.answers }
    $step = if ($saved -and $null -ne $saved.step -and $state -ne 'done') { [int]$saved.step } else { 0 }
    return [pscustomobject]@{ state = $state; step = $step; answers = $answers }
}

function Save-SnOnboarding {
    [CmdletBinding()]
    param([int]$Step = 0, $Answers)
    $saved = Read-SnOnboardingFile
    $base = if ($saved -and $saved.answers) { $saved.answers } else { [pscustomobject]@{} }
    $merged = if ($Answers) { Merge-SnObject $base $Answers } else { $base }
    $o = [pscustomobject][ordered]@{ step = $Step; answers = $merged; updatedAt = (Get-Now) }
    Write-Utf8 (Join-Path (Get-LearnDir) 'onboarding.json') ($o | ConvertTo-Json -Depth 10)
    return [pscustomobject]@{ ok = $true; state = (Get-SnOnboarding).state; step = $Step }
}

function Restart-SnOnboarding {
    <# Run onboarding again: answers start from what Stranote knows; nothing is deleted. #>
    $cur = Get-SnOnboarding
    $o = [pscustomobject][ordered]@{ step = 0; answers = $cur.answers; updatedAt = (Get-Now) }
    Write-Utf8 (Join-Path (Get-LearnDir) 'onboarding.json') ($o | ConvertTo-Json -Depth 10)
    $prof = Get-SnProfile
    if ($prof) {
        $prof.onboarding | Add-Member -NotePropertyName state -NotePropertyValue 'in-progress' -Force
        Write-Utf8 (Join-Path (Get-LearnDir) 'profile.json') ($prof | ConvertTo-Json -Depth 10)
    }
    return [pscustomobject]@{ ok = $true; state = 'in-progress' }
}

function Set-SnPath($Obj, [string]$Path, $Value) {
    # sets a.b.c on an object, creating levels as needed
    $parts = $Path.Split('.'); $o = $Obj
    for ($i = 0; $i -lt $parts.Count - 1; $i++) {
        if (-not $o.PSObject.Properties[$parts[$i]] -or $null -eq $o.($parts[$i])) { $o | Add-Member -NotePropertyName $parts[$i] -NotePropertyValue ([pscustomobject]@{}) -Force }
        $o = $o.($parts[$i])
    }
    $o | Add-Member -NotePropertyName $parts[-1] -NotePropertyValue $Value -Force
}

function Complete-SnOnboarding {
    [CmdletBinding()]
    param([string]$Today = (Get-Today))
    $a = (Get-SnOnboarding).answers
    if (-not "$($a.packId)") { throw 'Choose your career first.' }
    $pack = Get-SnPack -Id $a.packId
    $old = Get-SnProfile

    # 1. work root: only on a first onboarding (moving it later would hide existing data)
    $cfg = Get-SnConfig
    if (-not $old -and "$($a.workRoot)" -and "$($a.workRoot)" -ne "$($cfg.root)" -and -not $env:STRANOTE_LEARN_DIR) {
        if (-not [IO.Path]::IsPathRooted("$($a.workRoot)")) { throw 'Work folder must be a full path, like D:\Work.' }
        $saved = Read-SnOnboardingFile
        $cfg.root = "$($a.workRoot)"; Save-SnConfig $cfg
        if ($saved) { Write-Utf8 (Join-Path (Get-LearnDir) 'onboarding.json') ($saved | ConvertTo-Json -Depth 10) }
    }

    # 2. profile
    $roleId = if ($old -and @($old.roles).Count) { "$(@($old.roles)[0].id)" } else { 'r1' }
    $companies = @(); if ($old -and @($old.roles).Count) { $companies = @(@(@($old.roles)[0].companies) | Where-Object { $_ }) }
    if ("$($a.company)".Trim() -and $companies -notcontains "$($a.company)".Trim()) { $companies += "$($a.company)".Trim() }
    $roles = @([pscustomobject][ordered]@{ id = $roleId; packId = $pack.id; level = "$($a.level)"; years = $a.years; companies = $companies })
    if ($old -and @($old.roles).Count -gt 1) { $roles += @(@($old.roles) | Select-Object -Skip 1) }
    $ratings = [pscustomobject]@{}; $ratings | Add-Member -NotePropertyName $roleId -NotePropertyValue $(if ($a.ratings) { $a.ratings } else { [pscustomobject]@{} })
    $prof = [pscustomobject][ordered]@{
        schemaVersion = 1
        language = [pscustomobject]@{ explain = $(if ("$($a.language)") { "$($a.language)" } else { 'en' }); keepTermsInEnglish = $true }
        learningStyle = @($a.style); roles = $roles; ratings = $ratings
        goals = [pscustomobject]@{ focusAreas = @($a.focusAreas | Where-Object { $_ }); target = "$($a.target)"; dailyMinutes = [int]$(if ($a.dailyMinutes) { $a.dailyMinutes } else { 10 }); reviewTime = $(if ("$($a.reviewTime)" -match '^\d{2}:\d{2}$') { "$($a.reviewTime)" } else { '09:00' }) }
        privacy = [pscustomobject]@{ localOnly = @($a.localOnly); neverOnCv = @($a.neverOnCv) }
        packAnswers = [pscustomobject]@{}
        industry = "$($a.industry)"; workHours = "$($a.workStart)-$($a.workEnd)"
        onboarding = [pscustomobject]@{ state = 'done'; step = $null; completedAt = (Get-Now); source = 'wizard' }
    }

    # 3. pack questions: settings.* -> settings, profile.* -> profile, pack.* -> profile.packAnswers
    $settingWrites = @{}
    foreach ($q in @($pack.onboardingQuestions | Where-Object { $_ })) {
        if (-not $a.packAnswers -or -not $a.packAnswers.PSObject.Properties[$q.id]) { continue }
        $v = $a.packAnswers.($q.id); if ($null -eq $v -or "$v" -eq '') { continue }
        $w = "$($q.writesTo)"
        if ($w -like 'settings.*') { $settingWrites[$w.Substring(9)] = $v }
        elseif ($w -like 'profile.*') { Set-SnPath $prof $w.Substring(8) $v }
        else { $prof.packAnswers | Add-Member -NotePropertyName $(if ($w -like 'pack.*') { $w.Substring(5) } else { $q.id }) -NotePropertyValue $v -Force }
    }
    Save-SnProfile -SnProfile $prof | Out-Null

    # 4. settings (stored as your overrides on top of the pack): career, weekend, pack answers, task types
    $s = Get-SnSettings
    if ("$($a.company)".Trim()) {
        $name = "$($a.company)".Trim()
        $list = @(@($s.career.companies) | Where-Object { $_ })
        $hit = @($list | Where-Object { $_.name -eq $name })[0]
        if ($hit) {
            if ("$($a.title)" -and -not "$($hit.role)") { $hit.role = "$($a.title)" }
        } else {
            $start = if ("$($a.start)" -match '^\d{4}-\d{2}-\d{2}$') { "$($a.start)" } else { $Today }
            $list += [pscustomobject][ordered]@{ name = $name; role = "$($a.title)"; start = $start; end = '' }
        }
        $s.career.companies = @($list)
    }
    if (@($a.weekend | Where-Object { $_ }).Count) { $s.career.weekend = @($a.weekend | Where-Object { $_ }) }
    foreach ($k in $settingWrites.Keys) { Set-SnPath $s $k $settingWrites[$k] }
    $pick = @($a.taskTypes | Where-Object { $_ })
    if ($pick.Count) { $keep = @($s.types | Where-Object { $pick -contains $_.name }); if ($keep.Count) { $s.types = $keep } }
    $saveResult = Save-SnSettings -Settings $s

    # 5. self-ratings -> concept statuses (never lowers something you already learned)
    $concepts = (Get-SnTeach).concepts; $set = 0
    foreach ($r in @($a.ratings.PSObject.Properties)) {
        $status = $script:RatingStatus["$($r.Value)"]; if (-not $status) { continue }
        $area = @($pack.areas | Where-Object { $_.id -ieq $r.Name })[0]; if (-not $area) { continue }
        $keys = @('area:' + "$($area.id)".ToUpper()) + @(@($area.concepts) | Where-Object { $_ } | ForEach-Object { 'concept:' + $_.id })
        $go = @($keys | Where-Object { $cur = "$((Get-Prop (Get-Prop $concepts $_) 'status'))"; -not $cur -or $script:StatusRank[$status] -ge $script:StatusRank[$cur] })
        if ($go.Count) { Set-SnConceptStatus -Keys $go -Status $status -Source 'onboarding'; $set += $go.Count }
    }

    # 6. first-week plan
    $plan = New-SnFirstWeekPlan -Answers $a -Pack $pack -From $Today
    return [pscustomobject]@{ ok = $true; profile = $prof; createdFolders = @($saveResult.createdFolders); conceptsSet = $set; plan = $plan; reviewTime = $prof.goals.reviewTime }
}

function New-SnFirstWeekPlan {
    <# Starter lessons for areas you rated new/basic: goal areas first, new before basic, then pack order;
       10 minutes each, as many per day as your daily minutes allow, over 5 working days (weekend skipped). #>
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Answers, [Parameter(Mandatory)]$Pack, [string]$From = (Get-Today))
    $focus = @($Answers.focusAreas | Where-Object { $_ } | ForEach-Object { "$_".ToUpper() })
    $rate = @{}; foreach ($r in @($Answers.ratings.PSObject.Properties)) { $rate["$($r.Name)".ToUpper()] = "$($r.Value)" }
    $order = 0
    $areas = @(foreach ($ar in @($Pack.areas)) {
            $id = "$($ar.id)".ToUpper(); $order++
            if (@('new', 'basic') -notcontains $rate[$id]) { continue }
            $fi = [array]::IndexOf($focus, $id)
            [pscustomobject]@{ area = $ar; f = $(if ($fi -ge 0) { $fi } else { 999 }); r = $(if ($rate[$id] -eq 'new') { 0 } else { 1 }); o = $order }
        }) | Sort-Object f, r, o
    $items = New-Object System.Collections.ArrayList
    foreach ($x in $areas) {
        $cs = @(@($x.area.concepts) | Where-Object { $_ })
        if ($cs.Count) { foreach ($c in $cs) { [void]$items.Add([pscustomobject][ordered]@{ day = ''; areaId = "$($x.area.id)"; conceptId = "$($c.id)"; title = "$($c.title)"; minutes = 10; status = 'todo' }) } }
        else { [void]$items.Add([pscustomobject][ordered]@{ day = ''; areaId = "$($x.area.id)"; conceptId = ''; title = "$($x.area.name)"; minutes = 10; status = 'todo' }) }
    }
    $perDay = [Math]::Max(1, [Math]::Floor([int]$(if ($Answers.dailyMinutes) { $Answers.dailyMinutes } else { 10 }) / 10))
    $weekend = @($Answers.weekend | Where-Object { $_ })
    $d = [datetime]::ParseExact($From, 'yyyy-MM-dd', $null); $i = 0; $days = 0; $out = @()
    while ($i -lt $items.Count -and $days -lt 5) {
        if ($weekend -contains $d.DayOfWeek.ToString().Substring(0, 3)) { $d = $d.AddDays(1); continue }
        for ($k = 0; $k -lt $perDay -and $i -lt $items.Count; $k++) { $items[$i].day = $d.ToString('yyyy-MM-dd'); $out += $items[$i]; $i++ }
        $days++; $d = $d.AddDays(1)
    }
    $plan = [pscustomobject][ordered]@{ createdAt = (Get-Now); from = $From; perDay = $perDay; items = @($out) }
    Write-Utf8 (Join-Path (Get-LearnDir) 'plan.json') ($plan | ConvertTo-Json -Depth 6)
    return $plan
}

function Get-SnPlan {
    $p = Join-Path (Get-LearnDir) 'plan.json'
    if (-not (Test-Path $p)) { return [pscustomobject]@{ items = @() } }
    $o = [IO.File]::ReadAllText($p) | ConvertFrom-Json
    $o.items = @($o.items | ForEach-Object { $_ })
    return $o
}

function Set-SnPlanItem {
    [CmdletBinding()]
    param([Parameter(Mandatory)][int]$Index, [ValidateSet('todo', 'done', 'skipped')][string]$Status)
    $p = Get-SnPlan
    if ($Index -lt 0 -or $Index -ge @($p.items).Count) { throw "Plan item $Index not found." }
    $p.items[$Index].status = $Status
    Write-Utf8 (Join-Path (Get-LearnDir) 'plan.json') ($p | ConvertTo-Json -Depth 6)
    return $p.items[$Index]
}
