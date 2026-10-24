# Implementation Plan: Task attachments and report intake (new or fix)

**Branch**: `claude/AT0` (docs); build rows AT1-AT5 | **Date**: 2026-10-24 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/004-task-attachments-report-intake/spec.md`

## Summary

Intake questions get optional pack fields (`kind`, `options`, `required`, `when`, `askIfBlank`, `sub`) and task types
get optional `variants`, so a pack can branch Report into New / Fix with its own questions, checklist and object names.
One engine helper `Resolve-SnIntake` applies the rules for the dashboard, the terminal and agents. Attachments reuse
`Save-SnFile` with an `-Attachment` switch that saves under the new setting `attachmentsPath` inside the task folder.
The New task dialog gets an attachments area and file questions; the task page gets a quick Attach (paste / drop) and,
later, image previews. All EBS wording and report types live in the two EBS packs.

## Technical Context

**Language/Version**: Windows PowerShell 5.1 (engine, server); JavaScript in `src/dashboard_template.html` (page)

**Primary Dependencies**: none new (HttpListener, one HTML template, JSON packs)

**Storage**: pack JSON (intake fields, variants, `attachmentsPath`); `task.json` (additive `details[].k`,
`files[].question/original`); attachment files in the task folder of the work root

**Testing**: Pester 3.4 `tests/StranoteIntake.Tests.ps1` (helper, validation, `New-SnTask` per branch, attachments on a
temp root, no EBS words in template/engine); browser check of both dialogs in light, dark and 390 px

**Target Platform**: local Windows PC, browser on localhost

**Project Type**: local web app (PowerShell server + single-file page)

**Performance Goals**: dialog redraw on a choice < 50 ms; a 5 MB screenshot saved in < 3 s on the dev PC

**Constraints**: UTF-8 without BOM; Arabic file names kept; 50 MB per file; never write outside the work root; never
overwrite; template and engine free of EBS words (existing Pester gate)

**Scale/Scope**: 2 packs get the Report branch (+ `attachmentsPath` in all 6 packs); 2 dialogs; ~5 engine functions

## Constitution Check

*GATE: passes before research and after design.*

| Principle | Result |
|---|---|
| I. One engine, many careers | PASS: branching, report types and folder names are pack data; engine/page only read generic fields; the EBS-word gate covers the new code |
| II. Teach before quiz | PASS: no learning flow change; fix details feed knowledge capture as normal details |
| III. Local-first and private | PASS: files stay in the work folder; writes keep `X-EBS: 1`; preview route serves only images under the work root |
| IV. Never lose progress | PASS: additive fields, no migration; never overwrite files; Settings editor keeps unknown fields (R5); live `overrides.json` changes only with the owner's word and a backup |
| V. Own language | PASS: labels come from the pack; Arabic file names kept |
| VI. Test the engine, see the UI | PASS: Pester file per engine rule + browser matrix (tasks) |
| VII. Simple until proven | PASS: no new runtime; one helper, one switch, one setting |

No violations; Complexity Tracking not needed.

## Project Structure

### Documentation (this feature)

```text
specs/004-task-attachments-report-intake/
├── spec.md  plan.md  research.md  data-model.md  quickstart.md  tasks.md
├── contracts/intake-fields.md
└── checklists/requirements.md
```

### Source Code (repository root)

```text
src/
├── settings.default.json      # attachmentsPath = {ticket}\Attachments (AT1)
├── StranotePacks.ps1          # validate question fields + variants in the pack loader (AT1)
├── StranoteCore.ps1           # Resolve-SnIntake; New-SnTask uses it (+ -Attach paths, terminal prompts);
│                              # Assert-SnSettings validates the same fields; Save-SnFile -Attachment -Question;
│                              # Get-SnMeta sends full question objects + variants + attachmentsPath (AT1)
├── StranoteServer.ps1         # /api/savefile passes attachment/question; /api/file image preview (AT1, AT4)
└── dashboard_template.html    # New task dialog: choice/long/files, conditions, attachments, upload after create;
                               # Settings type editor keeps unknown fields (AT3); task page Attach + previews (AT4)
packs/oracle-ebs-technical.json, packs/oracle-ebs-functional-financials.json   # Report New/Fix (AT2)
packs/*.json                   # attachmentsPath (AT2)
specs/001-career-packs-onboarding/contracts/pack-schema.md   # pointer to contracts/intake-fields.md (AT1)
tests/StranoteIntake.Tests.ps1 # new (AT1, extended in AT2)
.agents/skills/ebs-task/SKILL.md, .agents/skills/ebs-dashboard-guide/SKILL.md, .agents/skills/stranote-dev/SKILL.md, README.md, docs/pack-authoring.md   # (AT5)
```

**Structure Decision**: single project, existing layout; the new rules sit next to the intake code they extend.

## Design decisions (details in research.md)

1. **Pack fields, not code** ([contract](contracts/intake-fields.md)): every new field is optional; a question without
   `kind` is today's text box.
2. **One rule set** (R4): `Resolve-SnIntake($typeDef, $answers)` -> `{ visible[], variant, askBusiness[] }`; the page has
   the same logic for drawing, the server re-checks on `/api/new`.
3. **Attachments** (R1, R2): `Save-SnFile -Attachment [-Question k]`; the dialog creates the task, then saves files one
   by one and reports failures by name.
4. **Settings stays lossless** (R5): the type editor copies unknown question/type fields through; a Pester case saves
   settings with the new fields and reads them back.
5. **Live data** (R5): the live upgrade checks `overrides.json` for `types` and asks the owner before merging the new
   Report questions (backup first).

## Delivery slices (board)

AT1 engine (fields, helper, validation, `New-SnTask`, `Save-SnFile -Attachment`, meta, server, tests) -> AT2 pack data
(both EBS packs + `attachmentsPath` in all packs, pack tests) -> AT3 New task dialog + Settings editor pass-through ->
AT4 task page Attach + previews -> AT5 skills, docs, live-upgrade note. AT2 can start when AT1's contract is merged;
AT3 and AT4 touch different parts of the template and can run in parallel after AT1.
