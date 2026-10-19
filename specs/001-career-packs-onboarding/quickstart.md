# Quickstart: validate career packs and onboarding

Prerequisites: Windows PowerShell 5.1, Pester 3.4 (built in), the repo at `D:\Projects\Ops`.

## 1. Engine tests
```powershell
Invoke-Pester D:\Projects\Ops\tests
```
Expected: all tests pass, including OpsPacks, OpsOnboarding and OpsMigrate.

## 2. Validate every shipped pack
```powershell
Import-Module D:\Projects\Ops\src\Stranote.psm1 -Force -DisableNameChecking
Get-ChildItem D:\Projects\Ops\packs\*.json | ForEach-Object { Test-SnPack -Path $_.FullName }
```
Expected: `ok = True` for each pack, no errors.

## 3. Migration on a copy of real data (US1, SC-002)
1. Copy `D:\Work` to `%TEMP%\ops-mig\Work` (never run the first migration on the live folder).
2. `Invoke-SnMigration -Root "$env:TEMP\ops-mig\Work" -WhatIf` -> lists what will be written.
3. Run without `-WhatIf`; then `Compare-SnSnapshot -Before <backup> -After <root>`.
Expected: 0 differences in tasks, cards, questions (box, due, hist), concepts, review-log; `profile.json` with role
`oracle-ebs-technical`; dashboard renders the same board.

## 4. New user onboarding (US2)
1. Start the server with an empty root: `StranoteServer.ps1 -Root "$env:TEMP\ops-new" -Port 8766`.
2. Open `http://localhost:8766/` -> the wizard appears.
3. Answer as "IT / ERP -> Oracle EBS Technical Consultant, Mid, 4 years", rate PL/SQL expert and OAF new, language
   Egyptian Arabic, Sun-Thu, review 09:00, goals OAF + Financials.
4. Close the browser at step 4, reopen -> wizard resumes at step 4.
5. Finish. Expected: board with first task prompt; Daily review shows "Today's new lesson: OAF ..."; PL/SQL questions
   are quiz-ready, OAF questions locked; work folders created; no console errors (light and dark).

## 5. Another career (US3)
Repeat step 4 with "Healthcare -> Nurse, Junior". Save `samples/nurse-shift.md` into a case task. Expected: ≥ 3
medication/procedure cards, a starter lesson, no EBS words anywhere in the UI.

## 6. Unlisted career (US4)
Onboard as "Civil site engineer" -> "My career is not listed". Expected: General pack active, request saved under
`pack-requests/`. In Claude: "build my Ops pack" -> draft validated -> accept in Settings > Roles.
