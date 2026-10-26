---
name: stranote-dev
description: Stranote developer rules - locked decisions (stack, naming, settings layering, packs, brand, UI), how to run and test, the live upgrade of D:\Work, and the file map. Load BEFORE changing, building, testing or running anything in Stranote's src/, tests/, packs/, docs/ or specs/, before a review of a branch that changes them, and before touching the live install D:\Work.
---

# Stranote - developer rules (every agent)

`AGENTS.md` has the always-on rules; this skill has what you need only when you work on the product itself.
The constitution (`.specify/memory/constitution.md`) wins over this file.

## Locked decisions
- Spec Kit flow; constitution has 7 principles: packs not code, teach-before-quiz, local-first / no secrets in the
  frontend, never lose progress, own language, test the engine + see the UI, simple stack.
- Stack stays: Windows PowerShell 5.1 + HttpListener + one HTML template + JSON. New runtime, framework or service:
  stop and ask the owner. Load `powershell51-gotchas` before writing PowerShell.
- Playbook: one phase at a time: spec -> owner approval -> build -> tests -> `PHASE_<X>_NOTES.md`; follow its
  Definition of Done (section 7). Agreed order (2026-10-20): playbook review (no code) -> test run + section 4
  performance baseline (numbers only) -> Phase A spec only, then wait for approval.
- Phase A candidate code is parked on local branch `phase-a-wip` (f30150d, not pushed) + `PHASE_A_NOTES.md`. Review
  it in the Phase A spec; do not merge before approval.
- Naming: functions `Verb-Sn*` (old `Verb-Ebs*/Verb-Ops*` kept as aliases in generated `src/StranoteAliases.ps1`,
  exported by `Stranote.psm1`); env `STRANOTE_{CONFIG,ROOT,LEARN_DIR,PACKS_DIR,NO_SCHEDULE}` (old `OPS_*` copied in at
  load); old-name wrappers `Ops.psm1`, `EbsTasks.psm1`, `EbsServer.ps1`, `OpsServer.ps1`, `EbsMenu.ps1`,
  `Start-OpsMorning.ps1`. Learn dir falls back to `04_Knowledge\Ops` if `Stranote` is missing (`Get-SnLearnDirFor`).
  Kept on purpose: skill names `ebs-task`/`ebs-dashboard-guide`, pack `oracle-ebs-technical`, localStorage `ebsView`,
  header `X-EBS`, card/question ids.
- Settings = `src/settings.default.json` <- active pack (`packs/<id>.json`) <- `overrides.json`; `profile.json`
  (roles -> packId); both in the learn dir. EBS specifics live in `packs/oracle-ebs-technical.json`.
- Dashboard wording comes from pack field `ui` (documented in `contracts/pack-schema.md`), sent as `META.pack`; the
  template keeps only neutral defaults. A Pester gate fails if EBS words come back into the template.
- Custom packs live in `<learn dir>\packs` (read first by `Get-SnPacksDirs`). Pack requests:
  `<learn dir>\pack-requests\<slug>.json`, status pending -> drafted -> accepted|rejected.
- Tests never touch real data: `tests/StranoteTestHelpers.ps1` (temp `STRANOTE_CONFIG` + `STRANOTE_LEARN_DIR`);
  fixture `tests/fixtures/ebs-legacy` keeps the legacy `04_Knowledge\Ops` layout on purpose (do not rename).
- Brand: logo "rising layers" (top bar indigo `#4F46E5`), files `src/brand/stranote-*` + `stranote.ico`. Accent
  indigo, learn accent `#2563EB`; the live app overrides both to Graphite `#3F3F46` (overrides.appearance).
- UI follows `docs/design/LINEAR_INSPIRED_UI_UX.md` (section 0: product brand/terms/workflows win; only look and feel
  changes). Check UI changes in light, dark and 390px width.
- Live upgrade = back up, copy `src\*` (except config/settings json) + `packs\` into `D:\Work\05_Tools\Stranote`,
  restart the server. Backups go to `D:\Work\06_Admin\Backups\stranote-upgrade-<timestamp>`. Only when the board
  row says so, one agent at a time. A pack change to task types (e.g. spec 004 Report New/Fix, spec 005 Data request)
  stays hidden when the live `overrides.json` holds its own `types` (migrated installs do): show the owner, and only
  with their word merge the new type / its `questions`/`variants` into `overrides.json` (backup first).
- Task intake (spec 004): optional question fields `kind`/`options`/`required`/`when`/`askIfBlank`/`sub` and type
  `variants` (pack data, `Resolve-SnIntake`); attachments via `Save-SnFile -Attachment` into `attachmentsPath`.
- Type layouts (spec 005): optional type fields `folders`/`saveTargets`(+`versioned`)/`attachmentsPath`/
  `useBaseChecklist`/`useCommonQuestions`/`phases` resolved by `Get-SnTypeLayout` (field-by-field fallback); save-place
  indexes are per task (`Get-SnTaskTargets`, page `taskLayout(t)`); versions are a file-name rule `<family>_v<n>`
  (`Get-SnFileFamily`, `Save-SnFile -VersionOf/-AsNew/-Note`, `GET /api/families`). Tests: `tests/StranoteLayout.Tests.ps1`.
- Commits: only on your own task branch; commits to `main`, merges and pushes only when the owner asks. Mark
  finished tasks `[X]` in `tasks.md` with the commit id.

## Run and test
- Live: `D:\Work\stranote.cmd` -> http://localhost:8765 (never use 8765 for testing). Live install
  `D:\Work\05_Tools\Stranote` (junction `05_Tools\EbsTasks`), data `D:\Work\04_Knowledge\Stranote`.
- Dev server: `powershell -ExecutionPolicy Bypass -File src\StranoteServer.ps1 -Port <first free from 8767> -Config <temp config.json>`
  with `STRANOTE_NO_SCHEDULE=1`.
- Tests: `powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Pester <worktree>\tests"`
  (Pester 3.4; run in a fresh process). Count on main: see `STATE.md`.
- Execution policy is Restricted: always `-ExecutionPolicy Bypass`. No python on this PC.
- Git is not on the PowerShell PATH: `& 'C:\Program Files\Git\cmd\git.exe'`. Commit messages: write a file and
  `git commit -F <file>`.

## File map
- `src/StranoteCore.ps1` core (tasks, settings, config, env fallback, exports `$script:SnExports`) · `src/Stranote.psm1`
- `src/StranotePacks.ps1` packs/profile/overrides · `src/StranoteMigrate.ps1` migration + snapshots
- `src/StranoteLearn.ps1` cards, auto knowledge, questions, CV, Arabic, `Get-LearnDir`/`Get-SnLearnDirFor`
- `src/StranoteTeach.ps1` lessons/follow-ups · `src/StranoteReview.ps1` daily review · `src/StranoteOnboarding.ps1`
- `src/StranoteServer.ps1` HTTP API · `src/Start-StranoteMorning.ps1` · `src/StranoteMenu.ps1` · `src/StranoteAliases.ps1`
- `src/dashboard_template.html` whole UI · `packs/*.json` · `tests/*.Tests.ps1` · `specs/001-*/*` · `docs/`
