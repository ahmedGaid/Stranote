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
   and each type's intake questions (`typeQuestions.<Type>` = list of `k` key / `q` question / `d` default, and
   optionally `kind` choice|long|files, `options`, `required`, `when` {k, is|in}, `askIfBlank`, `sub`).
   Then ask for what's missing. Use AskUserQuestion for choices (area/module, Type, Priority) in one call, then ask the
   free-text gaps (title, ticket ID - blank = auto, due date, requester, description, and the chosen type's questions)
   in one short chat message. Pass answers to `-Details` keyed by `k`.
   Don't interrogate: if the user doesn't know something, leave it blank; it becomes an open question.
   **Branching types** (e.g. EBS Report): ask the `choice` questions first (AskUserQuestion with their `options`;
   EBS Report: "New report or fix an existing one?"), then ask only the questions whose `when` matches the answer.
   For a Report **fix**, ask: report name / short name, its EBS report type (`rtype` options), where the current
   version is, responsibility, the parameter values that raise the problem, a request ID that shows it, the instance,
   what is wrong now, the correction needed, since when - and ask for screenshots / output files of the problem and
   of the expected result. `required` questions must be answered; blank `askIfBlank` questions become open questions.
   Hidden answers are dropped by the engine, so never send fix answers for a new report.
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
   Report fix with attachments (files are copied, originals untouched; `key=path` puts a file under that files
   question's sub-folder, a plain path goes to the attachments folder itself):
   ```powershell
   New-SnTask -NonInteractive -Title 'Supplier aging totals wrong' -Module AP -Type Report `
     -Details @{ mode='Fix an existing report'; rname='XX Supplier Aging (XXAPAGING)'; rtype='BI Publisher - data template (XML)';
                 fixParams='OU=Cairo; As of 30-SEP-2026'; wrong='Totals are doubled for invoices with 2 holds' } `
     -Attach @('problemFiles=C:\Users\me\Downloads\aging_output.xlsx', 'C:\Users\me\Downloads\email.msg')
   ```
   Check `AttachFailed` in the result and tell the user which files were not saved.
   **Data request** (EBS technical pack: a consultant asks for data from the DB by SQL): ask what data and why
   (`need`, required), instance, OU / ledger, filters, columns, output (`output` choice) and one time or recurring
   (`repeat` choice); their scripts / screenshots / sample sheets go in `-Attach` (they land in `01_From_Requester`).
   The task gets only the folders `01_From_Requester`, `02_Scripts`, `03_Data`, its own 6-item checklist (no
   MD050 / UAT / deploy items) and its own phases (Requested, Query written, Data sent, Confirmed, On Hold, Done).
   ```powershell
   New-SnTask -NonInteractive -Title 'AP invoices on hold' -Module AP -Type 'Data request' -Requester '...' `
     -Details @{ need='All AP invoices on hold for one OU since July'; instance='PROD'; scope='OU Cairo'; output='Excel sheet' } `
     -Attach @('C:\Users\me\Downloads\their_query.sql', 'C:\Users\me\Downloads\screen.png')
   ```
   Any type can have its own layout (`folders`, `saveTargets`, `attachmentsPath`, `useBaseChecklist`,
   `useCommonQuestions`, `phases`; see `(Get-SnMeta).typeLayouts.<Type>`); `New-SnTask` applies it by itself.
5. Report back briefly: folder created, proposed object names, the open questions to take to the business, and suggest the first step.

## Progress update

Map the user's words to parameters, then run `Update-SnTask`:

| User says | Parameter |
|---|---|
| "moved to testing", "in UAT" | `-Phase` one of the task type's phases: `$meta.typeLayouts.<Type>.phases` (EBS: Requirements/Design/Development/Testing/UAT/Deployment/On Hold/Done; Data request: Requested/Query written/Data sent/Confirmed/On Hold/Done) |
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
Destinations are per task type: `(Get-SnMeta).typeLayouts.<Type>.saveTargets` (index = `-Target`; the type's own places
first, then the general ones outside the task folder). Pick by name, never by a remembered index. Other packs have their
own list (General: Notes, File or attachment, How-to, Template, Certificate). EBS pack defaults:
0 task script (ticket\03_Dev\API, numbered), 1 deployment script (ticket\05_Deploy, numbered), 2 production code (repo; pass `-SubFolder 'db\packages'` etc.),
3 reusable snippet (04_Knowledge\SQL_Snippets\<module>), 4 requirements, 5 design, 6 test evidence.
Data request: Query script (`02_Scripts`, versioned), Data sheet (`03_Data`, versioned), From requester, then repo and snippet.

```powershell
Save-SnFile -Id 'CR-1042' -Target 0 -FileName 'create_invoice_api.sql' -Text $script -AddPrefix -AddHeader -Purpose '...'
```
Use `-Base64` for binary content. List a task's files with `Get-SnTaskFiles -Id X`.

**Versions** (never overwrite): before saving into a folder that already has files, list them with
`Get-SnFileFamilies -Id X -Target <n>` (or `-Attachment`) and decide - a changed query or a corrected sheet is a **new
version**, something else is a **new file**. Ask the user when it is not clear.
```powershell
Save-SnFile -Id 'T-0050' -Target 0 -FileName 'q.sql' -Text $sql -VersionOf 'AP_holds_query' -Note 'added supplier site'  # -> AP_holds_query_v3.sql
Save-SnFile -Id 'T-0050' -Target 1 -FileName 'AP_holds.xlsx' -Base64 $b64 -AsNew   # new file; refused if the name is taken
```
Versioned places name the first file `_v1`; a plain name counts as v1. The note goes to the task and `_NOTES.md`.

**Attachments** (screenshots, emails, sample outputs, mockups - input to the work, not deliverables) go to the task's
attachments folder (`(Get-SnMeta).typeLayouts.<Type>.attachmentsPath`; EBS: `<ticket>\01_Requirements\Attachments`;
Data request: `<ticket>\01_From_Requester` - the requester's own scripts and screenshots, kept apart from yours):
```powershell
Save-SnFile -Id 'CR-1042' -Attachment -SourcePath 'C:\Users\me\Downloads\wrong_totals.png' -FileName 'wrong_totals.png' -Question problemFiles
Save-SnFile -Id 'CR-1042' -Attachment -SubFolder 'Expected' -FileName 'expected.xlsx' -Base64 $b64
```
`-Question <files question key>` uses that question's sub-folder (EBS Report fix: `Problem`, `Expected`). Never
overwrites (`_v2`), 50 MB per file. In the dashboard: task page > **+ Attach** (drop, choose, or paste a screenshot or
text with Ctrl+V); the dashboard asks "new file or new version?" whenever the folder already has files.

## Other commands

- What am I working on: `Get-SnTask | Format-Table -AutoSize | Out-String -Width 200`, then summarize: blocked first, then overdue, then by priority. Point out tasks with no update for 3+ days (`updated` field).
- Details: `Show-SnTask -Id X`
- Close: `Close-SnTask -Id X -Note '...'` (confirm with the user first; it moves the folder to `99_Archive\<year>`)
- Dashboard: the live board (add/update/close in the browser) is started by `Start-Process D:\Work\stranote.cmd` and served at http://localhost:8765. `D:\Work\Dashboard.html` is a read-only snapshot refreshed after every change (`Update-SnDashboard -Open`).

Settings (prefix, modules, types, questions, checklists, phases, folders, naming): `D:\Work\05_Tools\Stranote\settings.json`,
edited by the user from the dashboard's Settings button. If the user asks you to change a setting, edit it via
`$s = Get-SnSettings; <change $s>; Save-SnSettings -Settings $s` (validates, backs up, creates new folders).
`config.json` holds only the root folder and the auto-ID counter.
