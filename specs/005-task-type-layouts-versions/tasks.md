# Tasks: Task-type layouts, Data request type and file versions

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/type-layout.md](contracts/type-layout.md)

**Rules**: no code before the owner approves the spec, and not before spec 004 (AT0-AT5) is merged. Format
`[ID] [P?] [Story] description + file`; `[P]` = can run in parallel (different files). Mark `[X]` with the commit id
when done. Each phase maps to a board row.

## Phase 1: Engine (board TL1) - blocks everything else

- [X] T001 [US1] Validate the type layout fields and `versioned` in the pack loader (`src/StranotePacks.ps1`, task-type block) per the contract, path-style messages (f8b3b77)
- [X] T002 [US1] Same validation for `types` / `saveTargets` in `Assert-SnSettings` (`src/StranoteCore.ps1`) (f8b3b77)
- [X] T003 [US1] `Get-SnTypeLayout($s, $typeDef)` resolver with field-by-field fallback (`src/StranoteCore.ps1`) (f8b3b77)
- [X] T004 [US1] `New-SnTask` uses it: type folders instead of `ticketFolders`; skip `baseChecklist` / `commonQuestions` when turned off; terminal path the same (f8b3b77)
- [X] T005 [US3] `Get-SnTaskTargets($task)` (type targets + general non-`{ticket}` targets); `Resolve-SnTarget`, `Get-SnTargetFolders` use it; `Resolve-SnAttachDir` reads the type's `attachmentsPath` (f8b3b77)
- [X] T006 [US2] `Get-SnFileFamily` (name rule) + `Get-SnFileFamilies -Id [-Target|-Attachment] [-SubFolder]` (f8b3b77)
- [X] T007 [US2] `Save-SnFile -VersionOf -AsNew -Note`: next version, `_v1` for the first file in a versioned place, refuse `-AsNew` on an existing name, record `family/version/follows/note`, `_NOTES.md` line; no flag = today's rule (f8b3b77)
- [X] T008 [US2] Server: `GET /api/families`; `/api/savefile` passes `versionOf` / `asNew` / `note`; `Get-SnMeta` sends layouts and per-task targets (`src/StranoteServer.ps1`, `src/StranoteCore.ps1`) (f8b3b77)
- [X] T009 [P] Pointer rows in `specs/001-career-packs-onboarding/contracts/pack-schema.md` -> `contracts/type-layout.md` (f8b3b77)
- [X] T010 [P] [US1] `tests/StranoteLayout.Tests.ps1` (Pester 3.4, temp data): validation errors; resolver fallback; New-SnTask with layout vs without (same as before, SC-004); targets list identical for types without `saveTargets`; family parsing (`x`, `x_v2`, `report_v7`, Arabic); versions, `_v1`, never overwrite, `-AsNew` refused; record fields; settings round-trip; no EBS words in template/engine (f8b3b77)

TL1 notes: the page already indexes save places per task (`taskLayout(t)` in the template, needed once a type has its own places). For TL4: the general save-destination editor rebuilds each place as name/path/prefix and would drop `versioned`; keep it there too.

**Checkpoint**: a test pack with a layout type creates the right folders/checklist from the terminal; versions saved by parameter.

## Phase 2: Pack data (board TL2) - needs T001-T007

- [ ] T011 [US1] `packs/oracle-ebs-technical.json`: Data request type per the contract example (questions, layout, places, checklist, open questions, Recurring variant)
- [ ] T012 [US1] Extend `tests/StranoteLayout.Tests.ps1`: every shipped pack loads; Data request creates 3 folders, 6 checklist items, no base items; Report/Interface unchanged; full suite green

## Phase 3: Page - versions and attachments (board TL3) - needs TL1, TL2

- [ ] T013 [US2] Version dialog before save (save panel upload + pasted script, Attach): families list, guess, note, apply-to-all, name clash -> version/rename; Cancel writes nothing (`src/dashboard_template.html`)
- [ ] T014 [US3] Attachments area accepts pasted text (name box, `.sql` guess) in the New task dialog and on the task page; New task dialog uses the type's attachments folder and says where files go
- [ ] T015 [US6] Task files list grouped by place and family; latest first with note; "older versions (n)" folded
- [ ] T016 Browser check light / dark / 390 px of the three areas; no console errors

## Phase 4: Settings type editor (board TL4) - needs TL1

- [ ] T017 [US4] Layout part per type: folders list + live preview, save places with versioned switch, attachments folder, two switches; empty folders = use general (field removed); unknown fields kept (`src/dashboard_template.html`)
- [ ] T018 [US4] Pester round-trip: save settings with layouts 5 times, read back identical; browser check light / dark / 390 px

## Phase 5: Skills, docs, live upgrade note (board TL5) - needs TL2

- [ ] T019 [P] [US5] `.agents/skills/ebs-task/SKILL.md`: Data request intake; `.agents/skills/ebs-dashboard-guide/SKILL.md`: where query / sheet / requester files go, save as next version with a note
- [ ] T020 [P] README.md + `docs/pack-authoring.md`: type layout fields and versions; `stranote-dev` file-map line
- [ ] T021 Live-upgrade note: check live `overrides.json` `types`; add Data request only on the owner's word, backup first

## Phase 6: Per-type phases (board TL6) - needs TL1, TL4 (owner choice Q3-B)

- [ ] T022 [US7] Validate `taskTypes[].phases` (pack loader + `Assert-SnSettings`): `Done` present, unique names, `column` in general phases, percent 0-100 (`src/StranotePacks.ps1`, `src/StranoteCore.ps1`)
- [ ] T023 [US7] Engine: `Get-PhaseNames` / `Get-PhasePct` take the task type; `New-SnTask` first phase, `Update-SnTask` choices + auto percent (keep the current phase if no longer listed); `Get-SnMeta` sends per-type phases, columns, percents
- [ ] T024 [US7] Page: update dialog offers the type's phases; board and list place cards by column and show the type phase label (`src/dashboard_template.html`)
- [ ] T025 [US7] Data request phases in `packs/oracle-ebs-technical.json` (FR-017); Settings type editor phases list (name, %, column), empty = general
- [ ] T026 [US7] Tests in `tests/StranoteLayout.Tests.ps1`: validation, first phase, update choices, removed phase kept, types without phases unchanged; browser check light / dark / 390 px
