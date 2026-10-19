# Implementation Plan: Career packs and first-day onboarding

**Branch**: `001-career-packs-onboarding` | **Date**: 2026-10-19 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-career-packs-onboarding/spec.md`

## Summary

Make the Ops engine career-agnostic by moving every Oracle EBS-specific setting and rule into a versioned JSON
**career pack**, add a **profile** that says which packs a person uses and how they rated themselves, and add a
first-run **onboarding wizard** that writes the profile, settings, folders, concept statuses, review schedule and a
first-week plan. The current EBS installation is migrated losslessly to the `oracle-ebs-technical` pack. Four more
packs and a General pack prove the engine works for other careers; unlisted careers get a pack drafted by Claude
from a saved pack request.

## Technical Context

**Language/Version**: Windows PowerShell 5.1 (server, engine, migration); vanilla JavaScript ES2020 in one HTML
template (UI)

**Primary Dependencies**: none beyond Windows (System.Net.HttpListener, Task Scheduler cmdlets); Pester 3.4 for
tests; Google Fonts (Inter, IBM Plex Sans Arabic, Readex Pro, JetBrains Mono)

**Storage**: JSON files. Product: `packs/*.json`, `settings.default.json`. Person: `<root>\04_Knowledge\Stranote\`
(cards, questions, concepts, lessons, review-log, profile.json, overrides.json, onboarding.json, plan.json,
pack-requests/)

**Testing**: Pester 3.4 against a temp `STRANOTE_LEARN_DIR` and a temp work root; browser checks with the in-app browser

**Target Platform**: Windows 10/11, current user, localhost:8765

**Project Type**: local desktop web app (PowerShell server + single-page HTML)

**Performance Goals**: pack load + validation < 300 ms; onboarding submit (folders + profile + plan) < 2 s;
knowledge sync unchanged from today (< 3 s for 50 tasks)

**Constraints**: offline-capable, localhost only, `X-EBS: 1` on writes, no secrets in the frontend, PS 5.1 syntax,
UTF-8 without BOM, lossless migration with backup

**Scale/Scope**: 1 person per install; ~6 packs; packs up to ~40 areas, ~20 task types, ~200 starter concepts

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Gate | Status |
|---|---|---|
| I. One engine, many careers | No career names, modules, regexes or folder names left in engine code; all come from the pack | PASS (moved to `packs/oracle-ebs-technical.json`; T031 greps the engine for leftovers) |
| II. Teach before quiz | Self-ratings map to concept statuses; "new" areas stay locked until taught | PASS (FR-007, reuses `Set-SnConceptStatus`) |
| III. Local-first and private | No new network calls; pack drafting via Claude sessions; CV privacy rules per profile | PASS |
| IV. Never lose progress | Backup + migration test comparing before/after on a copy of real data | PASS (T013-T017) |
| V. Learn in your own language | Language stored in profile and passed to lessons/explanations | PASS |
| VI. Test the engine, see the UI | Pester for loader, validator, onboarding, migration; browser check for wizard | PASS |
| VII. Simple until proven | Same stack; no new runtime | PASS |

Post-design re-check (after Phase 1): PASS. No violations; Complexity Tracking left empty.

## Project Structure

### Documentation (this feature)

```text
specs/001-career-packs-onboarding/
├── plan.md              # This file
├── research.md          # Phase 0: decisions
├── data-model.md        # Phase 1: pack, profile, overrides, onboarding answers
├── quickstart.md        # Phase 1: validation scenarios
├── contracts/
│   ├── pack-schema.md   # career pack JSON contract (schemaVersion 1)
│   └── http-api.md      # new and changed endpoints
├── checklists/requirements.md
└── tasks.md             # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

```text
D:\Projects\Ops\
├── src\
│   ├── Stranote.psm1              # module entry (today EbsTasks.psm1), dot-sources the files below
│   ├── StranotePacks.ps1          # NEW: Get-SnPack, Test-SnPack, Get-SnProfile, Get-SnEffectiveSettings, overrides
│   ├── StranoteOnboarding.ps1     # NEW: Save-SnOnboarding, Complete-SnOnboarding, New-SnFirstWeekPlan
│   ├── StranoteMigrate.ps1        # NEW: Invoke-SnMigration (EBS install -> profile + pack), Compare-SnSnapshot
│   ├── StranoteLearn.ps1          # knowledge, questions, CV (extractors read from the pack)
│   ├── StranoteTeach.ps1          # lessons, concepts, follow-ups (unchanged API)
│   ├── StranoteReview.ps1         # daily review (+ today's new lesson from plan.json)
│   ├── StranoteServer.ps1         # HTTP server (today EbsServer.ps1) + /api/packs, /api/profile, /api/onboarding
│   ├── EbsServer.ps1, EbsTasks.psm1   # thin wrappers -> keep shortcuts and skills working
│   ├── Start-StranoteMorning.ps1
│   ├── dashboard_template.html   # + onboarding wizard, Settings > Profile & roles
│   └── settings.default.json     # career-neutral defaults only
├── packs\
│   ├── oracle-ebs-technical.json
│   ├── oracle-ebs-functional-financials.json
│   ├── accountant.json
│   ├── software-developer.json
│   ├── nurse.json
│   └── general.json
├── tests\
│   ├── StranoteTeach.Tests.ps1, StranoteReview.Tests.ps1   # existing
│   ├── StranotePacks.Tests.ps1                        # NEW
│   ├── StranoteOnboarding.Tests.ps1                   # NEW
│   ├── StranoteMigrate.Tests.ps1                      # NEW
│   └── fixtures\ebs-snapshot\                    # anonymised copy of today's data shape
└── docs\pack-authoring.md
```

**Structure Decision**: Single project. Code is copied from `D:\Work\05_Tools\EbsTasks` into `src\` without any
personal data (no settings.json, config.json, backups or 04_Knowledge content). The person's install keeps running
from `D:\Work` until the new build passes the migration test on a copy; then an install step copies `src\` over
`D:\Work\05_Tools\EbsTasks`. Old file names stay as thin wrappers so `ebs.cmd`, `dashboard.cmd`, the desktop
shortcuts, the morning scheduled task and the Claude skills keep working (Constitution IV).

## Complexity Tracking

No violations.
