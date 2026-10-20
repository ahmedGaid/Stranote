# Playbook review (step 2): conflicts, backlog map, open points

2026-10-20 · Claude Code (Opus 5.5) · task P2 · no code changed.
Read: `STRANOTE_LINEAR_PLAYBOOK.md`, `.specify/memory/constitution.md` (1.0.0), `LOCAL_FIRST_AUDIT.md`,
`PHASE_A_NOTES.md`, `specs/001-career-packs-onboarding/` (tasks), `specs/002-phase-a-safety/spec.md` (Codex draft),
`PHASE_BASELINE.md`, plus a grep of `src/` and `packs/` to check facts.

**Short version.** The playbook and the constitution agree on the big things (stack, local-first, packs as data,
never lose progress). There are **4 real conflicts** that need an owner decision or a constitution amendment, and
**6 unclear points** that will cause rework if an agent guesses. Nothing blocks the owner's review of the Phase A
spec (board P3) today.

---

## (a) Conflicts

| # | Conflict | Where | Proposed resolution | Who |
|---|---|---|---|---|
| C1 | **Phase C "change journal" vs anti-goal "no sync log for the single-PC product".** A `changes.jsonl` + `GET /api/changes?since=` is what a sync log looks like. | Playbook §6 Phase C vs §8; audit §9 also recommends the journal | Reword §8 to "no *replication* (IndexedDB copy, WebSockets, offline replay)"; a local change *feed* for refresh is allowed. Same as board P5. | owner |
| C2 | **`X-EBS: 1` header is written into the constitution.** Phase I wants every EBS name out of the core, but renaming this header changes a principle. | Constitution §III; playbook §3.3; `StranoteServer.ps1:117`, `dashboard_template.html:940,3088` | Amend §III (PATCH) to "a custom write header (today `X-EBS: 1`)"; in Phase I accept both `X-EBS` and a neutral `X-Stranote` for one release, then drop the old one. | owner (amendment) |
| C3 | **Shipped packs have unreviewed domain content.** Guardrail 6 and Lesson 4 require `TODO(practitioner)` marks and a real reviewer per non-owner career; `accountant`, `nurse`, `software-developer` and `oracle-ebs-functional-financials` have neither (grep: no `TODO(`, `x-unconfirmed` or reviewer field in `packs/`). The playbook's beachhead order also says one excellent pack at a time; four are already shipped. | Playbook §2 L3/L4, §3.6, §8; constitution §I | Add an `x-unconfirmed` list (the field `stranote-pack-builder` already uses) or a `review` block (`status`, `reviewer`) to each pack; show "not yet reviewed by a practitioner" in onboarding for those packs. Do not delete them. | owner decides; then any agent |
| C4 | **Which plan is running: Spec 001 or the playbook?** Playbook §10.4 says "start Phase A, do not start any other phase", but Spec 001 still has US5 (T043-T045), T046, T047, T049 open, and the board lists S1/S2 as open. | Playbook §0, §10; `specs/001-*/tasks.md` Phases 7-8 | Owner picks one: (1) freeze Spec 001 until Phase A merges, or (2) let S1/S2 run in parallel on branches, with Phase A's write inventory updated for the profile/role writes T043 adds. Recommendation: (1) for S1 (it adds writers that Phase A must cover), (2) for S2 (skills only). | owner |

Smaller inconsistencies (no decision needed, fix when the file is next edited):
- Playbook §1 and §3.4 say **106 tests**; main has **113** (and the Phase A candidate 125). Say "all existing tests".
- Playbook §4 "Inline payload … today 409 KB with 2 tasks" measures the **whole page**, not the inline data: the empty
  template alone is 283 KB (`src/dashboard_template.html`). See U2 below.
- `tasks.md` T046 still names the skill `ops-learn`; it is `stranote-learn` now (`.agents/skills/`).
- Constitution workflow requires the full Spec Kit chain (plan, tasks, analyze) per feature; the playbook's loop
  says "a short spec". Constitution wins: after P3 approval, Phase A still needs `plan.md` and `tasks.md` in
  `specs/002-phase-a-safety/` before code.
- Playbook §3.3 promises "no telemetry leaving the machine", but the template loads fonts from Google's CDN (board
  D2). That is a request to a third party on every load; self-host or use the system font stack (playbook §5.4
  already allows either).

## (b) Backlog -> playbook phase map

| Board / backlog item | Playbook phase | Notes |
|---|---|---|
| P1 performance baseline (Codex, in progress) | §4 + §10.2, before Stage 1 | Cold `GET /` 1339 ms is over the 1 s budget; Phase B lazy-loading is the planned fix |
| P3 Phase A scope, P4 forward-port f30150d | **Stage 0 Phase A** | P4 must add T040-T042 writes (pack requests, custom packs, `Approve-SnPackDraft` multi-file switch) |
| Audit open Q4 "keep `Dashboard.html`?" | Phase B (owner decision §9.3) | Regenerated on every write today; dropping it also speeds every write |
| Lazy-load `explain-ar`, lessons, history/files | Phase B | Main lever for the 1 s / 150 KB budgets |
| P5 journal wording; audit Q2 "skills via module or HTTP?" | Phase C | Q2 decides where the journal lives |
| Task patches instead of `reload()` | Phase D | |
| E2 context menu, styled tooltips | Phase G / H | Keyboard path + `?` overlay required (DoD) |
| U1 dark scrollbar; D2 brand gaps (logo bar colour, CV export red `#C74634`, learn-accent fallback, 3 inline logos, Google Fonts) | **Phase H** (design system, §5.4 tokens) | One token pass fixes most of D2; needs owner's colour choices first |
| U2 CV privacy warning text; D1 `01_Tasks` vs `01_Tickets`; core Technical/Financial/Business/SCM fallback; E1 `skillMap` / `starterLessons` unused | **Phase I** (career-agnostic core) | E1 = playbook §5.2 `skills[]` and `starterLessons[]` |
| S2 / T046 skills read the active pack | Phase I (+ Stage 3 "pack-aware agents") | Can run now: skills only, no core change |
| S1 / T043-T045 second role | Spec 001 US5; playbook L3 "several packs" + I2 | Adds profile/role writes: after Phase A or inside its inventory (C4) |
| S3 / T047 docs, T049 release checks | Spec 001 close-out | After S1/S2 |
| Missing everywhere: `CHANGELOG.md`, `DESIGN_SYSTEM.md`, `src/design-tokens.css` | DoD (every phase) / Phase H | CHANGELOG is required from the next merged phase |
| O1 T-0001 screenshots | none (user data) | |

## (c) Unclear or wrong for this codebase

| # | Point | Why it matters | Suggested answer |
|---|---|---|---|
| U1 | **"Duty" vs "task".** The playbook says the core speaks of *duties*; code, API, files and packs say *task* (`task.json`, `/api/tasks`, `taskTypes`, `New-SnTask`). | A rename would touch every layer and stored data (constitution §IV). | Keep `task` in code and data; "duty" is only a possible UI label, which packs already control through `ui`. |
| U2 | **"Inline payload < 150 KB"**: whole page or data only? | Template is 283 KB, so the whole-page reading can never pass. | Budget = inline **data** (today ~62 KB with 100 synthetic tasks), plus a separate template-size budget if wanted. |
| U3 | **Playbook §5.2 pack schema** (`vocabulary`, `phases[]`, `dutyTypes[]`, `skills[]`, `exampleDuty`) vs the **existing schema** (`ui`, `settings.phases`, `taskTypes`, `skillMap`, `starterLessons`; `contracts/pack-schema.md`). | Agents could add a second set of fields that duplicate the first. | Treat §5.2 as concepts, not field names: extend the existing fields; bump `schemaVersion` only for real additions. |
| U4 | **"No career terms in core" test**: one exists for the template only (AGENTS.md); the playbook wants it for all core files. | `src/*.ps1` still hold EBS terms (list below). | Phase I extends the Pester gate to `src/*.ps1` with an allow-list for migration code and comments. |
| U5 | **Phase A locking vs the audit's compare-and-swap.** The candidate uses a named mutex + atomic replace; the audit proposed a `rev` per file. | Mutex covers module/server/menu writers but not stale whole-object browser saves (settings, CV). | Fine for Phase A (Codex's spec lists it as a boundary, P3). If the owner wants stale browser saves fixed, that is the `rev` idea and an API change (later phase). |
| U6 | **"Owner used it on a real duty"** (DoD) for Stage 0 phases that change no UI. | Hard to "use" safety. | For Phase A/B: one normal working day on the upgraded live install, with no errors in `locks.log` / `morning.log`. |

### EBS-specific names in the core (for Phase I, do not rename now)

| Name | Where | Note |
|---|---|---|
| `X-EBS: 1` write header | `StranoteServer.ps1:117`, `dashboard_template.html:940`, `:3088`; constitution §III | Needs amendment (C2) |
| `ebsView` localStorage key | `dashboard_template.html:976-977` | Rename with a one-time read of the old key |
| Categories Technical / **Financial** / Business / **SCM** + `financialModules` | `dashboard_template.html:1211-1212,1231`; `StranoteLearn.ps1:632,648-649` | Move to the EBS pack; core fallback = one neutral category |
| "internal custom object names" CV warning | `dashboard_template.html:1873` | Pack `ui` text (board U2) |
| Oracle red `#C74634` | CV export `dashboard_template.html:2310,2827`; example in error text `StranoteCore.ps1:100` | Use the accent token; neutral example |
| Pre-migration fallback to the EBS pack | `StranotePacks.ps1:158`, `StranoteLearn.ps1:126`, `StranoteMigrate.ps1` | Legitimate (legacy installs were EBS); keep, allow-list in the gate |
| `01_Tickets` task folder | engine default; packs list an unused `01_Tasks` | Board D1 |
| Old names kept on purpose | `Verb-Ebs*` aliases, `EbsTasks.psm1`, `EbsServer.ps1`, `EbsMenu.ps1`, junction `05_Tools\EbsTasks`, skills `ebs-task` / `ebs-dashboard-guide`, pack id `oracle-ebs-technical` | Compatibility; review in Phase I, keep aliases one release |

## Decisions for the owner (in order)

1. **P3**: approve the Phase A scope limits (Explorer edits, stale browser saves, multi-file atomicity), or change them.
2. **C4**: Spec 001 remainder now or after Phase A (recommendation: S2 now, S1 after Phase A).
3. **C1 / P5**: allow a local change feed (reword the anti-goal).
4. **C2**: amend constitution §III to a neutral header name (can wait until Phase I).
5. **C3**: how to mark unreviewed packs, and who reviews the accountant / nurse / developer packs.
6. **U2**: what the 150 KB payload budget measures.
