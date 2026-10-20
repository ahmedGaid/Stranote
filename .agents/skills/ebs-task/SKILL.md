---
name: ebs-task
description: Manage the user's work tasks in Stranote (D:\Work), in the words of the active career pack (Oracle EBS for this user) - create a new task (intake questions, ticket folder, checklist, object names), record progress, answer open questions, list/show/close tasks and refresh the dashboard. Use when the user says "new task", "new EBS task", "I got a ticket", "progress on <ID>", "update <ID>", "what am I working on", "my tasks", "close <ID>", or pastes a ticket/email describing work to track.
---

# Stranote Task Manager

All logic lives in the PowerShell module `D:\Work\05_Tools\Stranote\Stranote.psm1`. Always call it; never hand-create ticket folders or edit `task.json` directly. Every call starts with:

```powershell
Import-Module 'D:\Work\05_Tools\Stranote\Stranote.psm1' -Force -DisableNameChecking
```

Always pass `-NonInteractive` to `New-SnTask` (the shell has no console input). `Update-SnTask` is non-interactive whenever any change parameter is passed.

## 0. Read the active career pack (first, every time)

Stranote works for any career. Lists and wording come from the person's **active career pack**, so read it first:

```powershell
$pack = Get-SnPackOrLegacy   # active pack (old installs: the EBS pack); $null = not onboarded yet, use neutral words
"$($pack.id) | $($pack.name) | $($pack.field)"
$meta = Get-SnMeta           # modules (= the pack's areas), types, priorities, phases, saveTargets, typeQuestions
```
- Use the pack's words: `$pack.ui.area` / `$pack.ui.areas` for what this skill calls a module, `$pack.ui.workspace`
  for the board, the names in `$pack.taskTypes` and `$pack.areas`. Never offer a value that is not in `Get-SnMeta`.
- EBS-only content below (AP/GL examples, MOAC, API vs interface table, repo sub-folders, SQL snippets) applies only
  when `$pack.id -like 'oracle-ebs-*'`. For any other pack use the same commands with that pack's lists.

## New task

1. Extract what you can from the user's message / pasted ticket or email.
2. The user edits all lists in the dashboard Settings, so never assume them. First run
   `Get-SnMeta | ConvertTo-Json -Depth 6` to get the current modules, types, priorities (and default), phases,
   and each type's intake questions (`typeQuestions.<Type>` = list of `k` key / `q` question / `d` default).
   Then ask for what's missing. Use AskUserQuestion for choices (area/module, Type, Priority) in one call, then ask the
   free-text gaps (title, ticket ID - blank = auto, due date, requester, description, and the chosen type's questions)
   in one short chat message. Pass answers to `-Details` keyed by `k`.
   Don't interrogate: if the user doesn't know something, leave it blank; it becomes an open question.
3. Add task-specific questions you, as an experienced practitioner of the pack's field (`$pack.field`), would want
   confirmed via `-ExtraQuestions` (EBS: MOAC/OU security, API vs interface table, seeded object to copy). Never invent
   domain facts for a career you are unsure of; ask the user instead.
4. Run (EBS pack example):
   ```powershell
   New-SnTask -NonInteractive -Id 'CR-1042' -Title '...' -Module AP -Type Interface -Priority P2 -Due '2026-11-15' `
     -Requester '...' -Description '...' -ShortCode 'INV_INT' `
     -Details @{ direction='Inbound'; system='Coupa'; transport='CSV over SFTP' } `
     -ExtraQuestions @('Invoice import via AP_INVOICES_INTERFACE or AP API?')
   ```
   Use single quotes; double any apostrophe inside values. Due accepts `yyyy-MM-dd` or `+N` days.
5. Report back briefly: folder created, proposed object names, the open questions to take to the business, and suggest the first step.

## Progress update

Map the user's words to parameters, then run `Update-SnTask`:

| User says | Parameter |
|---|---|
| "moved to testing", "in UAT" | `-Phase` one of `$meta.phases` (EBS: Requirements/Design/Development/Testing/UAT/Deployment/On Hold/Done) |
| "about 60%" | `-Percent 60` (omit to auto-set from phase) |
| what they did | `-Note '...'` |
| "blocked by DBA / waiting for ..." | `-Blocker '...'`; "unblocked" -> `-ClearBlocker` |
| "finished the concurrent program registration" | `-Check <n>` (run `Show-SnTask -Id X` first to get the numbers) |
| "business said columns are final" | `-Question <n> -Answer '...'` |
| new thing to confirm | `-AddQuestion '...'` |
| new date / priority | `-Due`, `-Priority` |

One `Update-SnTask` call can combine several parameters, except one `-Question/-Answer` pair per call.
If the update is vague, ask one short follow-up (phase? blocker?) before writing.

## Saving scripts / files for a task

When the user gives you a script or file for a task, save it with `Save-SnFile` (never write into ticket folders by hand).
Destinations come from settings (`(Get-SnMeta).saveTargets`, index = `-Target`); pick by name, never by a remembered
index. Other packs have their own list (General: Notes, File or attachment, How-to, Template, Certificate). EBS pack defaults:
0 task script (ticket\03_Dev\API, numbered), 1 deployment script (ticket\05_Deploy, numbered), 2 production code (repo; pass `-SubFolder 'db\packages'` etc.),
3 reusable snippet (04_Knowledge\SQL_Snippets\<module>), 4 requirements, 5 design, 6 test evidence.

```powershell
Save-SnFile -Id 'CR-1042' -Target 0 -FileName 'create_invoice_api.sql' -Text $script -AddPrefix -AddHeader -Purpose '...'
```
Use `-Base64` for binary content. List a task's files with `Get-SnTaskFiles -Id X`.

## Other commands

- What am I working on: `Get-SnTask | Format-Table -AutoSize | Out-String -Width 200`, then summarize: blocked first, then overdue, then by priority. Point out tasks with no update for 3+ days (`updated` field).
- Details: `Show-SnTask -Id X`
- Close: `Close-SnTask -Id X -Note '...'` (confirm with the user first; it moves the folder to `99_Archive\<year>`)
- Dashboard: the live board (add/update/close in the browser) is started by `Start-Process D:\Work\stranote.cmd` and served at http://localhost:8765. `D:\Work\Dashboard.html` is a read-only snapshot refreshed after every change (`Update-SnDashboard -Open`).

Settings (prefix, modules, types, questions, checklists, phases, folders, naming): `D:\Work\05_Tools\Stranote\settings.json`,
edited by the user from the dashboard's Settings button. If the user asks you to change a setting, edit it via
`$s = Get-SnSettings; <change $s>; Save-SnSettings -Settings $s` (validates, backs up, creates new folders).
`config.json` holds only the root folder and the auto-ID counter.
