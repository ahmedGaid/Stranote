# Tasks: Task attachments and report intake (new or fix)

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/intake-fields.md](contracts/intake-fields.md)

**Rules**: no code before the owner approves the spec (approved 2026-10-24: "ok do it now", defaults Q1-Q3). Format `[ID] [P?] [Story] description + file`;
`[P]` = can run in parallel (different files). Mark `[X]` with the commit id when done. Each phase maps to a board row.

## Phase 1: Engine (board AT1) - blocks everything else

- [X] T001 [US1] Validate the new question fields and `variants` in the pack loader (`src/StranotePacks.ps1`, task-type block) per the contract, with path-style messages (2bf09b7)
- [X] T002 [US1] Same validation for `types` in `Assert-SnSettings` (`src/StranoteCore.ps1`), so a bad Settings save is refused (2bf09b7)
- [X] T003 [US1] `Resolve-SnIntake($typeDef, $answers)` in `src/StranoteCore.ps1`: visible questions, matched variant, `askIfBlank` open questions, `required` / `options` checks (2bf09b7)
- [X] T004 [US1] `New-SnTask` uses it: hidden answers dropped, `details[].k` stored, variant lists replace the type's, `askIfBlank` questions added; terminal prompts: choice by number, multi-line (blank line ends), skip hidden (`src/StranoteCore.ps1`) (2bf09b7)
- [X] T005 [US2] `attachmentsPath` setting (engine default `{ticket}\Attachments` in code, not in `settings.default.json`), validated (starts with `{ticket}`, `Test-RelPath`); `Save-SnFile -Attachment [-Question k]` resolves it (+ `sub`), records `question` / `original` (2bf09b7)
- [X] T006 [US4] `New-SnTask -Attach <paths>` copies each file via the same attachment path (originals untouched); per-file errors reported, task kept (2bf09b7)
- [X] T007 [US1] `Get-SnMeta` sends full question objects and `attachmentsPath` (variants stay server-side: the page does not need them); `/api/new` passes answers to the helper; `/api/savefile` passes `attachment` / `question` (`src/StranoteServer.ps1`) (2bf09b7)
- [X] T008 [P] Add the pointer rows to `specs/001-career-packs-onboarding/contracts/pack-schema.md` -> `contracts/intake-fields.md` (2bf09b7)
- [X] T009 [P] [US1] `tests/StranoteIntake.Tests.ps1` (Pester 3.4, temp data): validation errors; helper per branch; New-SnTask New vs Fix vs type without branch (same as before, SC-004); `askIfBlank`; attachment save, `_v2`, Arabic name, outside-root refused; `-Attach`; settings save keeps fields; no EBS words in template/engine (2bf09b7)
- [X] T010 R3 check: save a 20 MB file via `/api/savefile` on a temp root; 20 MB saved in 4.8 s, no parser change needed (2bf09b7)

**Checkpoint**: a test pack with a New/Fix branch creates correct tasks from the terminal; attachments land in place.

## Phase 2: Pack data (board AT2) - needs T001-T005

- [X] T011 [P] [US1] `packs/oracle-ebs-technical.json` Report: `mode` choice, today's questions under New, fix questions (spec US1 list, report-type options), 2 file questions (`Problem`, `Expected`), Fix variant (open questions, checklist, objects); `attachmentsPath` `{ticket}\\01_Requirements\\Attachments` (11fb3bd)
- [X] T012 [P] [US1] `packs/oracle-ebs-functional-financials.json` Report: same branch, worded for a functional consultant; same `attachmentsPath` (11fb3bd)
- [X] T013 [P] [US2] `attachmentsPath` in `packs/accountant.json`, `packs/general.json`, `packs/nurse.json`, `packs/software-developer.json` (inside their first ticket folder) (11fb3bd)
- [X] T014 [US1] Extend `tests/StranoteIntake.Tests.ps1`: every shipped pack loads; both EBS Report types produce the fix checklist for Fix and the old one for New; full suite green (11fb3bd)

## Phase 3: New task dialog + Settings editor (board AT3) - needs AT1, AT2

- [X] T015 [US1] `renderTypeBlock` draws `kind` (text, long, choice, files), applies `when` live, marks `required` (`src/dashboard_template.html`, new task) (741b8c2)
- [X] T016 [US2] Attachments area for every type: drop, choose, paste image (R6), remove before Create, 50 MB check; file questions as their own areas (741b8c2)
- [X] T017 [US2] Submit: `/api/new`, then one `/api/savefile` per file with `attachment` + `question`; progress; failures listed by name with "add it from the task page" (741b8c2)
- [X] T018 [US1] Settings > Task types editor copies unknown question / type fields through on save (FR-012); simple editing of `kind` / `options` is out of scope (pack JSON) (741b8c2)
- [X] T019 [US1] Browser check (quickstart 1-7, 9, 11): light, dark, 390 px, no console errors (741b8c2)

## Phase 4: Task page (board AT4) - needs AT1

- [X] T020 [US3] Attach button next to "+ Save a file or script": drop / choose / paste into the attachments place with optional sub-folder; list refreshes (`src/dashboard_template.html`, files panel) (7a4b138)
- [X] T021 [P] [US5] GET `/api/file?path=` for images under `01_Tickets` / `99_Archive` only (`src/StranoteServer.ps1`, R7) + Pester case for refused paths (7a4b138)
- [X] T022 [US5] Files list: image previews grouped Problem / Expected / other; click opens; fix details shown as a block (7a4b138)
- [X] T023 [US3] Browser check (quickstart 8, 11): light, dark, 390 px (7a4b138)

## Phase 5: Skills, docs, live note (board AT5)

- [X] T024 [P] [US4] `.agents/skills/ebs-task/SKILL.md`: Report intake asks New/Fix and the fix questions; attachments go to the attachments folder (AT5)
- [X] T025 [P] `.agents/skills/ebs-dashboard-guide/SKILL.md`: screenshots / sample outputs -> attachments folder (AT5)
- [X] T026 [P] `README.md` user section (attachments, report fix) + `docs/pack-authoring.md` (intake fields); `stranote-dev` file map line (AT5)
- [X] T027 Live-upgrade note for the next upgrade row (R5): check live `overrides.json` for `types`; offer the owner a merge of the Report questions with a backup first; no live change in this row (AT5)
- [X] T028 Final: full Pester suite, quickstart 1-11, log line in `STATE.md` (AT5: suite 243/243; quickstart 1-9 and 11 in headless Edge; 10 via Pester -Attach, the interactive terminal prompts were not run by hand)

## Dependencies

T001-T003 -> T004-T007 -> T009. AT2 needs T001-T005. AT3 needs AT1 + AT2. AT4 needs AT1 (parallel with AT3: different
template parts). AT5 last. Phase A (board P4) changes `New-SnTask` / `Save-SnFile` later and rebases onto AT1 (R8).
