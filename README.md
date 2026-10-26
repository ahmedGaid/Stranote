# Stranote

Stranote turns your daily work, in any career, into lasting knowledge: it records your tasks, captures what you learned,
teaches it first, makes you recall it on a spaced schedule (daily review), and turns it into skills and CV lines.

## Layout
- `src/` - the app: PowerShell 5.1 engine + local server (`StranoteServer.ps1`) + one HTML dashboard.
  `Stranote.psm1` is the module; `EbsTasks.psm1` and `EbsServer.ps1` are kept as wrappers so old shortcuts keep working.
- `packs/` - career packs (JSON). Everything career-specific lives here: areas, categories, task types, folders,
  save destinations, knowledge extractors, starter lessons, skill map, onboarding questions.
- `tests/` - Pester 3.4 tests (`Invoke-Pester D:\Projects\Stranote\tests`). They run on throw-away copies only.
- `specs/` - Spec Kit features (spec, plan, tasks). `.specify/memory/constitution.md` holds the project rules.

## How settings work
`settings.default.json` (career-neutral engine defaults) <- active career pack <- `overrides.json` (your own changes,
stored in `<work root>\04_Knowledge\Stranote`). Your profile (`profile.json`, same folder) says which pack you use.

## Attachments and report intake
- **Attach files to a task**: in the New task dialog (Attachments area) or later on the task page (**+ Attach**):
  drop files, choose them, or click the area and paste a screenshot (Ctrl+V). They are saved in the task's own
  folder (`attachmentsPath` from the pack; Oracle EBS: `01_Requirements\Attachments`), never overwritten, max 50 MB
  each. Images show a preview on the task page.
- **Report: new or fix** (Oracle EBS packs): a Report task first asks "New report or fix an existing one?". A fix asks
  which report, its EBS report type, where the current version is, the parameters that raise the problem, what is
  wrong and the correction needed, with drop areas for problem and expected-result files (`Problem` / `Expected`
  sub-folders). Blank gaps become open questions. Other packs can branch any task type the same way
  (`docs/pack-authoring.md`).

## Task-type layouts and file versions
- **Each task type can have its own layout**: sub-folders, save places, attachments folder, checklist (with or
  without the common one) and phases. Settings > Task types > Layout; empty parts use the general settings.
  Existing tasks keep what they were created with.
- **Data request** (Oracle EBS technical): a consultant asks for data by SQL. The task gets `01_From_Requester`
  (their scripts and screenshots), `02_Scripts` (your queries) and `03_Data` (the sheets you send), a short data
  checklist, and the phases Requested, Query written, Data sent, Confirmed, Done.
- **New file or new version?** Saving or attaching into a folder that already has files asks first. A new version is
  saved as `<name>_v2`, `_v3` ... next to the earlier ones (never overwritten), with an optional "what changed" note;
  the task page shows the latest version first and folds the older ones. Pasted text can be saved as a file too.

## Upgrading an existing Oracle EBS install
On first start the server runs `Invoke-SnMigration`: it backs up to `06_Admin\Backups\ops-migration-<time>`,
writes `profile.json` (pack `oracle-ebs-technical`) and `overrides.json` (only your changes), checks that the
effective settings are identical to the old ones, and rolls back if not. Tasks and learning data are not touched.
To undo by hand: delete `profile.json` and `overrides.json`; the old `settings.json` is left in place.

## Run
```powershell
powershell -ExecutionPolicy Bypass -File src\StranoteServer.ps1            # uses src\config.json (created on first run)
powershell -ExecutionPolicy Bypass -File src\StranoteServer.ps1 -Port 8766 -Config C:\path\to\config.json
```
