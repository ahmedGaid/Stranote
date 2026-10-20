---
description: "Task list for 001 career packs and first-day onboarding"
---

# Tasks: Career packs and first-day onboarding

**Input**: Design documents from `/specs/001-career-packs-onboarding/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Included. Constitution VI requires Pester tests for engine logic and a browser check for UI.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: User story (US1-US5)

## Phase 1: Setup (Shared Infrastructure)

- [X] T001 Copy engine code from `D:\Work\05_Tools\EbsTasks` to `src\` (EbsTasks.psm1, StranoteLearn.ps1, StranoteTeach.ps1, StranoteReview.ps1, EbsServer.ps1, Start-StranoteMorning.ps1, StranoteMenu.ps1, dashboard_template.html, settings.default.json, brand\, tests\) with NO config.json, settings.json, settings.backup.json or personal data
- [X] T002 [P] Add `.gitignore` (personal data, backups, `*.log`, `packs/custom/`) and `README.md` with run instructions
- [X] T003 [P] Add `-Config` and `-Port` parameters to the server and `STRANOTE_CONFIG` / `STRANOTE_ROOT` overrides in `Get-SnConfig` so tests and the quickstart can run against a temp work root
- [X] T004 Run the existing 33 Pester tests from `tests\` to prove the copy works unchanged

---

## Phase 2: Foundational (Blocking Prerequisites)

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T005 [P] Write failing tests for pack loading and validation in `tests\StranotePacks.Tests.ps1` (valid minimal pack, duplicate area id, unknown category, bad regex, slow regex, unknown top-level field, x- field allowed)
- [X] T006 Implement `Test-SnPack` and `Get-SnPack` in `src\StranotePacks.ps1` per `contracts/pack-schema.md` (JSON path in each error, 200 ms regex timeout)
- [X] T007 Implement `Get-SnProfile` / `Save-SnProfile` (profile.json, schemaVersion 1, default `onboarding.state = required`) in `src\StranotePacks.ps1`
- [X] T008 Implement `Get-SnEffectiveSettings` = engine defaults <- pack.settings <- overrides.json, and make `Get-SnSettings` call it; `Save-SnSettings` writes only the diff to overrides.json (research R4)
- [X] T009 [P] Write tests for settings merge and override persistence across a pack version bump in `tests\StranotePacks.Tests.ps1`
- [X] T010 Create `src\Stranote.psm1` (dot-sources all files, exports `Ops*` and existing `Ebs*` functions); turn `src\EbsTasks.psm1` and `src\EbsServer.ps1` into thin wrappers (research R9)
- [X] T011 Add `GET /api/packs`, `GET /api/packs/get`, `GET /api/profile` to `src\StranoteServer.ps1` per `contracts/http-api.md`

**Checkpoint**: packs load and validate; settings come from defaults + pack + overrides.

---

## Phase 3: User Story 1 - Existing Oracle EBS user keeps everything (Priority: P1) 🎯 MVP

**Goal**: Everything EBS-specific lives in `packs\oracle-ebs-technical.json`; the current install migrates with zero loss.

**Independent Test**: quickstart §3 on a copy of `D:\Work`: 0 differences.

### Tests for User Story 1

- [X] T012 [P] [US1] Build an anonymised fixture of today's data shape in `tests\fixtures\ebs-snapshot\` (2 tasks, cards incl. auto API/table, questions with box/due/hist, concepts, lessons, review-log, settings.json with user edits)
- [X] T013 [P] [US1] Write failing migration tests in `tests\StranoteMigrate.Tests.ps1`: backup created; profile with role `oracle-ebs-technical`; overrides = user edits only; tasks/cards/questions/concepts/review-log byte-identical; second run is a no-op
- [X] T014 [P] [US1] Write failing extractor parity test: run old `Get-AutoKnowledge` and new pack-driven extraction on the fixture tasks; same card ids, topics, facts and question ids

### Implementation for User Story 1

- [X] T015 [US1] Create `packs\oracle-ebs-technical.json`: areas from modules (GL, AP, AR, FA, CE, PA, XLA, ZX, IBY, IEX, OKL, PO, INV, OM, ONT, WSH, BOM, WIP, MRP, CST, QP, ASCP, PON, ICX, WMS, EAM, FND, PLSQL, OAF, WF, BIP, FORMS), categories Technical/Financial/Business/SCM, task types, folders, saveTargets, abbreviations, stopWords, skillMap, onboardingQuestions (prefix, EBS version, DB version, environments, ticket format) moved from `settings.default.json`
- [X] T016 [US1] Move the API/table regexes and member blacklist from `Get-TaskCodeFacts` and `Get-SnSuggestions` (`src\StranoteLearn.ps1`) into pack `extractors`; implement `Invoke-SnExtractors` keeping `A-<md5>` ids (research R3)
- [X] T017 [US1] Make `Get-CardAutoCategory` read area -> category from the pack instead of `knowledge.financialModules/scmModules`
- [X] T018 [US1] Strip EBS content from `src\settings.default.json` (keep career-neutral defaults only)
- [X] T019 [US1] Implement `Invoke-SnMigration -Root [-WhatIf]` and `Compare-SnSnapshot` in `src\StranoteMigrate.ps1` (backup to `06_Admin\Backups\ops-<date>`, compute overrides, write profile with onboarding `done`)
- [X] T020 [US1] Run migration automatically on server start when `profile.json` is missing but `settings.json` exists (log to `morning.log`-style `migrate.log`)
- [X] T021 [US1] Run quickstart §3 on a copy of `D:\Work`; then browser-check the dashboard (board, knowledge faces, review, quiz) for no visible change

**Checkpoint**: MVP. The current user can switch to the new build with nothing lost.

> Done 2026-10-19: 59 Pester tests pass. Rehearsal on a copy of D:\Work: 0 task/learning files changed, overrides = appearance + career only, same 2 tasks / 13 modules / 9 types / 35 cards (19/7/8/1 by category) / 56 questions, Settings save round-trip clean, no console errors. Found and fixed an old bug: single-procedure API questions lost the procedure name (`\$proc?` parsed as a variable). Live install upgraded 2026-10-19 11:50 (T048): backup D:\Work\06_Admin\Backups\ops-upgrade-20261019-114949, migration backup ops-migration-20261019-115037, 0 task/learning files changed.

---

## Phase 4: User Story 2 - First-day onboarding for a new user (Priority: P1)

**Goal**: A new user completes a 5-minute wizard and lands on a configured board with a first-week plan.

**Independent Test**: quickstart §4 (EBS mid-level) and §5 (nurse) on empty roots.

### Tests for User Story 2

- [x] T022 [P] [US2] Write failing tests in `tests\StranoteOnboarding.Tests.ps1`: save/resume steps; complete writes profile, career entry, weekend, review time; ratings -> concept statuses (expert=known, comfortable=understood, basic=taught, new=new); folders created only when missing; plan orders goal areas first and fits daily minutes; pasted CV never reaches cv.json
- [x] T023 [P] [US2] Write test: questions of an area rated new are not quiz-ready until its lesson check passes (SC-005)

### Implementation for User Story 2

- [x] T024 [US2] Implement `Save-SnOnboarding`, `Complete-SnOnboarding`, `Restart-SnOnboarding` in `src\StranoteOnboarding.ps1` (uses `Set-SnConceptStatus -Source onboarding`, `Save-SnSettings`, folder creation)
- [x] T025 [US2] Implement `New-SnFirstWeekPlan` (research R6) writing `plan.json`; add "Today's new lesson" to `Get-SnDailyReview`
- [x] T026 [US2] Update `Start-StranoteMorning.ps1 -Install -Time` to be called from onboarding with the chosen review time
- [x] T027 [US2] Add `POST /api/onboarding/save|complete|restart` and `GET /api/plan` to `src\StranoteServer.ps1`
- [x] T028 [US2] Build the wizard in `src\dashboard_template.html`: steps You -> Field & role & level -> Rate your areas -> The job (pack onboardingQuestions) -> How work arrives -> Learning goals -> Privacy -> Optional CV -> Summary; progress bar, back/next, resume, Arabic learning text, learning accent and visual faces for areas
- [x] T029 [US2] Settings > Profile & roles tab: edit every answer, "Run onboarding again"
- [x] T030 [US2] Browser-check quickstart §4 in light and dark, phone width, no console errors

**Checkpoint**: New users get a working, personal Ops on day one.

---

## Phase 5: User Story 3 - Ready packs for other careers (Priority: P2)

**Goal**: The engine is proven career-agnostic.

**Independent Test**: quickstart §2 and §5.

- [x] T031 [US3] Grep `src\*.ps1` and `dashboard_template.html` for EBS words (FND_, XXCUST, GL_, Oracle, modules list) outside comments and packs; fix any leftover (Constitution I gate)
  - Done 2026-10-19: new optional pack field `ui` (labels, placeholders, CV title/tips, skill rules, bullet) sent as
    `META.pack`; EBS pack carries the old strings, so skills/CV drafts are identical (checked old vs new template
    on the fixture). `.ps1` hits were comments + the intended legacy fallback (now `Get-SnPackOrLegacy`). Test gate in
    `StranotePacks.Tests.ps1` keeps the template free of EBS words (only `X-EBS` and `ebsView` kept on purpose).
- [x] T032 [P] [US3] Write `packs\oracle-ebs-functional-financials.json` (GL/AP/AR/FA/CE setups, period close, configurations, test scripts)
  - Done 2026-10-19: 17 areas (11 task modules incl. CLOSE, SYSADMIN, IBY, ZX, XLA), 9 task types (Setup, Period close, Requirements,
    Testing, Data load, Support, Report, Training, Other), functional phases (CRP, Go-live), full `ui` block. Extractors: 2 `term`
    (setup terms, profile options; produce cards once the engine runs `term`, T037) + 1 `table`. `starterLessons` still empty.
- [x] T033 [P] [US3] Write `packs\accountant.json` (IFRS/GAAP terms, month-end close, reconciliations, accruals, tax)
  - Done 2026-10-19: 14 areas (11 task modules: GL, CLOSE, RECON, AP, AR, FA, TAX, REPORTING, AUDIT, BUDGET, PAYROLL + Other;
    STANDARDS and TOOLS as knowledge areas), 9 task types (Month-end close, Reconciliation, Journal entry, Tax filing, Financial
    statements, Audit support, Budget / forecast, Query / support, Other), accounting phases, full `ui` block ("Area" noun).
    Extractors: 3 `term` (IFRS/IAS/ASC standards, accounting concepts, tax terms), no code extractors. `starterLessons` empty.
- [x] T034 [P] [US3] Write `packs\software-developer.json` (languages, frameworks, PRs, incidents, design decisions)
  - Done 2026-10-19: 14 areas (12 task modules: FRONTEND, BACKEND, API, DATA, BUGFIX, TESTING, REVIEW, DESIGN, DEVOPS, INCIDENT,
    SECURITY + Other; LANGUAGES and FUNDAMENTALS as knowledge areas), 9 task types (Feature, Bug fix, Incident, Code review,
    Design / ADR, Spike / research, Refactor / tech debt, Deployment / release, Other), dev phases, full `ui` block ("Area").
    Extractors: 3 `term` (languages/frameworks, engineering concepts, ops tools). No `api` kind (engine's api is package.member
    shaped). Bare `Go`/`Express` left out of the languages regex (false hits at sentence start). `starterLessons` empty.
- [x] T035 [P] [US3] Write `packs\nurse.json` (units, procedures, medications, protocols, handover)
  - Done 2026-10-19: 15 areas (12 task modules: ASSESS, MEDS, IV, PROC, RESP, CARDIO, EMERG, INFECT, HANDOVER, SAFETY, EDU
    + Other; PHARM, PATHO, PROF as knowledge areas), 8 task types (Patient case, Procedure, Medication administration, Handover,
    Incident / near miss, Admission / discharge, Training / competency, Other), nursing phases, full `ui` block ("Nursing
    workspace"; `privateNames` flags MRN / bed / room / DOB). Extractors: 3 `term` (drugs, procedures/devices, clinical
    scores; the scores regex is case-sensitive so "news"/"must" do not match). No patient data in placeholders. `starterLessons` empty.
- [x] T036 [P] [US3] Write `packs\general.json` (minimal areas from free text, generic task types)
  - Done 2026-10-19: 7 areas, all task modules (PLANNING, COMMUNICATION, PROBLEM, PROJECT, LEARNING, ADMIN + Other), 6 task
    types (Task, Meeting, Problem / issue, Learning, Project, Other), 4 categories (Work, People, Growth, Tools), generic
    phases, neutral `ui` ("Workspace", "Professional" CV title). "Areas from free text": onboarding questions save job title,
    work areas and daily tools to `profile.packAnswers` (`jobTitle`, `workAreas`, `tools`) for the T042 pack builder.
    Extractors: 1 `term` (everyday office tools: Excel, Power BI, Jira, SharePoint...). `starterLessons` empty.
- [x] T037 [US3] Add `samples\<pack>\` work files and a test that each pack yields ≥ 10 cards from 5 samples (SC-004)
  - Done 2026-10-19: engine runs `term` extractors (`Get-TaskTermFacts` + term cards in `Get-AutoKnowledge`, StranoteLearn.ps1):
    case-insensitive count per task, `minCount`, `maxCards`, `cardTemplate` {key}/{taskId}/{context}, `group` -> card
    category + tag; `Test-SnPack` rejects a `group` that is not a category id. `samples\<pack-id>\` holds 5 fictional work
    files for each of the 6 packs. `tests\StranoteSamples.Tests.ps1`: one task per sample, Sync-SnKnowledge, >= 10 cards
    per pack (got 25-43), every card in a pack category + term-extractor unit tests. 102 tests pass.
- [x] T038 [US3] Write `docs\pack-authoring.md` (how to write and validate a pack)
  - Done 2026-10-20: where packs live, settings layering, every top-level field with an example, extractor kinds + worked `term` example, speed rule (250 ms / 50 KB), `Test-SnPack`, 5 samples + samples test, dev-server check, checklist. Notes `skillMap`/`starterLessons` are not read by the engine yet. Contract speed rule corrected to 250 ms.

---

## Phase 6: User Story 4 - A pack for any other career (Priority: P3)

- [x] T039 [US4] "My career is not listed" path in the wizard: free-text areas and tasks -> `POST /api/packs/request`; General pack active meanwhile
  - Done 2026-10-20: wizard card "My career is not listed" (step 2) opens job title, field, work areas, typical tasks, tools; Next
    calls `POST /api/packs/request` -> `New-SnPackRequest` writes `<learn dir>\pack-requests\<slug>.json` { slug, career, field,
    level, freeAreas[], freeTasks[], tools[], roleId, status: pending, draftPath, createdAt, updatedAt }; same career again
    updates the pending request; slug never shadows a shipped pack id (`-custom`). Role stays on `general` (its job / workAreas /
    tools answers are pre-filled). Custom packs live in `<learn dir>\packs` (read first by `Get-SnPacksDirs`), not `packs\custom\`.
    Fix found on the way: completing onboarding on any non-EBS pack threw (packs list `01_Tasks`, engine requires `01_Tickets`);
    `Get-SnBaseSettings` now always adds the required work folders. 106 tests pass.
- [ ] T040 [US4] `Get-SnPackRequest`, `Approve-SnPackDraft` (validate, copy to `<learn dir>\packs\`, switch role) and `POST /api/packs/accept`
- [ ] T041 [US4] Settings > Roles: pending request, draft preview (areas, task types), Accept / Reject
- [ ] T042 [US4] Write the `ops-pack-builder` Claude skill: read `pack-requests/<slug>.json`, draft `<learn dir>/packs/<slug>.json`, run `Test-SnPack`, set status `drafted`

---

## Phase 7: User Story 5 - Switching or combining roles (Priority: P3)

- [ ] T043 [US5] `POST /api/profile/role`; tasks, cards and questions get `roleId` (derived when missing, no rewrite)
- [ ] T044 [US5] Role picker in New task (default = current company's role); Knowledge/Skills filter by role
- [ ] T045 [US5] Test: adding a second pack keeps old cards' areas and the career counter history

---

## Phase 8: Polish & Cross-Cutting Concerns

- [ ] T046 [P] Update Claude skills (`ebs-task`, `ebs-dashboard-guide`, `ops-learn`) to read the active pack instead of assuming EBS
- [ ] T047 [P] Update `README.md` and the dashboard help for packs and onboarding
- [X] T048 Install step: copy `src\` over `D:\Work\05_Tools\EbsTasks` after a backup; run migration; restart server
- [ ] T049 Run the full quickstart and all Pester tests; record results in `specs/001-career-packs-onboarding/checklists/release.md`

---

## Dependencies & Execution Order

- Setup (T001-T004) -> Foundational (T005-T011) -> US1 (T012-T021) -> US2 (T022-T030) -> US3 / US4 / US5 -> Polish.
- US2 depends on US1 because onboarding writes through the same pack-driven settings.
- US3 packs (T032-T036) can be written in parallel once T006 validation exists.
- US4 needs T042 (the `ops-pack-builder` skill).

## Parallel Opportunities

- T002, T003; T005 and T009; T012, T013, T014; T022, T023; T032-T036; T046, T047.

## Implementation Strategy

1. MVP = Setup + Foundational + US1: same app for the current user, built on packs.
2. Add US2: anyone can onboard on day one.
3. Add US3 packs, then US4 and US5.
4. Stop at each checkpoint, run the quickstart section, then continue.
