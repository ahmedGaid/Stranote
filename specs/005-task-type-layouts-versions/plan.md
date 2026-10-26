# Implementation Plan: Task-type layouts, Data request type and file versions

**Branch**: `claude/TL0` (docs, stacked on `claude/AT5`); build rows TL1-TL6 | **Date**: 2026-10-26 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/005-task-type-layouts-versions/spec.md`

## Summary

Task types get optional layout fields (`folders`, `saveTargets`, `attachmentsPath`, `useBaseChecklist`,
`useCommonQuestions`) so a pack can give a type its own sub-folders, save places, requester folder and checklist.
`New-SnTask` reads them through one resolver; types without them keep today's general settings. File versions are one
naming rule (`<family>_v<n>`) in `Save-SnFile` with `-VersionOf` / `-AsNew` / `-Note`, plus a read-only family list
the page uses to ask "new file or new version?" before every save into a non-empty folder. The EBS technical pack gets
a Data request type. All wording, folder names and the type itself are pack data.

## Technical Context

**Language/Version**: Windows PowerShell 5.1 (engine, server); JavaScript in `src/dashboard_template.html` (page)

**Primary Dependencies**: none new (HttpListener, one HTML template, JSON packs)

**Storage**: pack JSON (type layout fields, `versioned` on save targets); `task.json` (additive `files[].family /
version / follows / note`); files in the task folder of the work root

**Testing**: Pester 3.4 `tests/StranoteLayout.Tests.ps1` (layout resolver, validation, `New-SnTask` with and without a
layout, family parsing, versions, never overwrite, settings round-trip, no EBS words); browser check of the version
dialog, attachments paste-text and the type editor in light, dark and 390 px

**Target Platform**: local Windows PC, browser on localhost

**Project Type**: local web app (PowerShell server + single-file page)

**Performance Goals**: family list for a folder of 200 files < 300 ms; version dialog opens < 100 ms after the list

**Constraints**: UTF-8 without BOM; Arabic names kept; 50 MB per file; never write outside the work root; never
overwrite; existing tasks never changed; template and engine free of EBS words (existing Pester gate)

**Scale/Scope**: 1 new type in 1 pack; ~6 engine functions touched or added; 3 page areas (save panel + Attach, files
list, type editor) and the New task dialog attachments

## Constitution Check

*GATE: passes before research and after design.*

| Principle | Result |
|---|---|
| I. One engine, many careers | PASS: layout, folders, Data request wording are pack data; engine/page read generic fields; EBS-word gate covers new code |
| II. Teach before quiz | PASS: no learning flow change; data-request details feed knowledge capture as normal details |
| III. Local-first and private | PASS: files stay in the work folder; no database connection; writes keep `X-EBS: 1`; families route is read-only and under the work root |
| IV. Never lose progress | PASS: additive fields; no migration; existing tasks untouched; never overwrite; no rename of old files; editor keeps unknown fields; live `overrides.json` only with the owner's word + backup |
| V. Own language | PASS: labels from the pack; Arabic names kept; dialog text neutral |
| VI. Test the engine, see the UI | PASS: one Pester file + browser matrix (tasks) |
| VII. Simple until proven | PASS: no new runtime; versions are a file-name rule, not a store; one resolver, one family function |

No violations; Complexity Tracking not needed.

## Project Structure

### Documentation (this feature)

```text
specs/005-task-type-layouts-versions/
├── spec.md  plan.md  research.md  data-model.md  quickstart.md  tasks.md
├── contracts/type-layout.md
└── checklists/requirements.md
```

### Source Code (repository root)

```text
src/
├── StranotePacks.ps1          # validate layout fields + versioned in the pack loader (TL1)
├── StranoteCore.ps1           # Get-SnTypeLayout resolver; New-SnTask uses it (folders, checklist, questions);
│                              # Get-SnTaskTargets (type + non-ticket general); Resolve-SnTarget/Resolve-SnAttachDir
│                              # read the type; Get-SnFileFamily / Get-SnFileFamilies; Save-SnFile -VersionOf -AsNew
│                              # -Note; Assert-SnSettings validates the same fields; Get-SnMeta sends layouts (TL1)
├── StranoteServer.ps1         # GET /api/families; /api/savefile passes versionOf/asNew/note (TL1)
└── dashboard_template.html    # version dialog in save panel + Attach; paste-text attachments; files grouped by
                               # place/family (TL3); Settings type editor Layout part + preview (TL4)
packs/oracle-ebs-technical.json   # Data request type (TL2)
specs/001-career-packs-onboarding/contracts/pack-schema.md   # pointer to contracts/type-layout.md (TL1)
tests/StranoteLayout.Tests.ps1 # new (TL1, extended in TL2)
.agents/skills/ebs-task/SKILL.md, .agents/skills/ebs-dashboard-guide/SKILL.md, .agents/skills/stranote-dev/SKILL.md,
README.md, docs/pack-authoring.md   # (TL5)
```

**Structure Decision**: single project, existing layout; the layout resolver sits next to `Get-TypeDef` and the intake
helper from spec 004.

## Design decisions (details in research.md)

1. **Layout is optional type data** (R1): one resolver `Get-SnTypeLayout($s, $typeDef)` returns folders, targets,
   attachments path and the two switches, falling back to the general settings field by field.
2. **Save-target indexes are per task** (R2): the page and API use the resolved list from `Get-SnTaskTargets`, so a
   type's places and the general non-ticket places share one index space; old tasks of a type without `saveTargets`
   get exactly today's list and indexes.
3. **Versions are a naming rule** (R3): `<family>_v<n>`; plain name = v1; no index file, no rename of old files; the
   task record adds family/version/follows/note for the page.
4. **Ask in the page, state in the API** (R4): the page asks before saving when the family list is not empty; the API
   takes `versionOf` / `asNew`; terminal and agents pass parameters; old callers keep today's free-name rule.
5. **Lossless Settings** (R5): the type editor gets the layout fields and still copies unknown fields through.
6. **Live data** (R6): the live upgrade checks `overrides.json` `types` and adds Data request only on the owner's word.
7. **Per-type phases** (R8, owner Q3-B): `taskTypes[].phases` with a board `column`; one board, cards placed by column
   and labelled with their own phase; `Done` / `On Hold` keep their meaning.

## Delivery slices (board)

TL1 engine (layout fields + validation, resolver, `New-SnTask`, per-task targets, families, versions in `Save-SnFile`,
server, meta, tests) -> TL2 pack data (Data request in EBS technical, pack tests) -> TL3 page: version dialog (save
panel + Attach), paste-text attachments, New task dialog uses the type's attachments folder, files grouped by family ->
TL4 Settings type editor Layout part -> TL5 skills, docs, live-upgrade note -> TL6 per-type phases (engine, Data
request phases, board/update dialog, Settings phases list, tests). TL2 can start when TL1's contract is merged; TL3 and
TL4 touch different parts of the template and can run in parallel after TL1; TL6 after TL4 (same type editor).
