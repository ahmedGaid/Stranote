# Feature Specification: Task attachments and report intake (new or fix)

**Feature Branch**: `claude/AT0` (spec); build rows AT1-AT5

**Created**: 2026-10-24

**Status**: Draft - waits for owner approval before AT1

**Input**: Owner request (2026-10-24): "I need to be able to add attachments to a task and it will be in its place in
the work folder, and if the task is a report I need the app to ask me if it's new or a fix of an old one, and if it is
old I need it to ask me where the old one is, the parameters that raise the problem and the type of that report in EBS
report types, and attach an image or file with the problem and the correction that we need, and so on."

## What exists today (baseline)

- The task page has **"+ Save a file or script"**: upload files or paste a script into one of the pack's save
  destinations (for EBS technical: `03_Dev\API`, `05_Deploy`, the Git repo, ...). Files are recorded on the task and
  listed under the task's files.
- The **New task** dialog has no file picker. Attachments can only be added after the task is created.
- Task-type intake questions are flat text boxes (`k`, `q`, default). A Report task asks technology, output format,
  parameters, frequency and "based on a seeded report? (blank = new)". There is no "new or fix" branch, no choice
  lists and no question that shows only for some answers.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Report task asks "new or fix", and a fix gets the right questions (Priority: P1)

The person creates a task of type **Report**. The first detail question is **"New report or fix an existing one?"**
(two choices). For **New**, the dialog shows today's new-report questions. For **Fix an existing report**, it shows the
fix questions instead:

1. Report name as users see it (concurrent program name) and its short name
2. Report type in EBS (choice list from the pack, e.g. Oracle Reports (RDF), BI Publisher with RDF data model,
   BI Publisher with data template, BI Publisher with PL/SQL / XML, SQL*Plus or PL/SQL text output, FSG, Discoverer,
   Web ADI / Excel, OAF page, Other)
3. Where the current version lives (server path such as `$XX_TOP/reports/US/XX.rdf`, template code, Git path)
4. Responsibility / request group it runs from
5. Parameters that raise the problem (the exact values)
6. A request ID of a run that shows the problem (optional)
7. Instance where it was seen (PROD / UAT / DEV ...)
8. What is wrong now (current result) - long text
9. The correction needed (expected result) - long text
10. Since when / what changed recently (optional)
11. Files that show the problem (screenshots, output, log) - file picker
12. Files that show the expected result (mockup, corrected Excel, email) - file picker

The fix task gets its own open questions, checklist and object names (the existing report's objects, not new ones),
for example "Reproduced with the same parameters", "Root cause found", "Fix tested with the same parameters",
"Old vs new output compared", "FNDLOAD / template backup taken before the change".

**Why this priority**: report fixes are a large share of the owner's daily EBS work; today the key facts (which
report, which parameters, what is wrong, what is wanted) are scattered in emails and get lost.

**Independent Test**: create a Report task, choose Fix, answer some fix questions, leave some blank, submit; the task
shows the answered fix details, the fix checklist, and every blank fix question as an open question for the business.

**Acceptance Scenarios**:

1. **Given** the New task dialog with type Report, **When** the person has not chosen New or Fix yet, **Then** only the
   New/Fix choice is shown in the details block and the task cannot be created until one is chosen.
2. **Given** New is chosen, **When** the dialog redraws, **Then** today's new-report questions show and no fix question
   shows; the created task has today's new-report checklist and open questions (no change for new reports).
3. **Given** Fix is chosen, **When** the dialog redraws, **Then** the fix questions show, the report type is a choice
   list, the two "what is wrong" / "correction needed" answers are multi-line, and the new-report questions are hidden.
4. **Given** Fix with parameters and request ID left blank, **When** the task is created, **Then** "Parameters that raise
   the problem" and "Request ID that shows the problem" become open questions on the task, so they are not forgotten.
5. **Given** the person switches from Fix back to New before creating, **When** they create the task, **Then** no fix
   answer is saved on the task.
6. **Given** a task type with no New/Fix choice (e.g. Interface), **When** the person creates it, **Then** the dialog and
   the created task are exactly as today.

---

### User Story 2 - Attach files while creating any task (Priority: P1)

In the New task dialog there is an **Attachments** area for every task type: drop files, choose files, or paste a
screenshot (Ctrl+V). For a Report fix the two file questions (problem / expected result) are their own drop areas.
When the task is created, each file is saved in the task's own folder in the work folder, in the pack's attachments
place (EBS packs: `01_Tickets\<task folder>\01_Requirements\Attachments`, with `Problem` and `Expected` sub-folders for
the fix files). The task records each file, `_NOTES.md` logs it, and the task page lists it.

**Why this priority**: the owner asked for it first; requirement screenshots and the business's sample output are the
input to the work and belong next to it from minute one.

**Independent Test**: create a task with two dropped files and one pasted screenshot; open the task folder in Explorer
and see the three files in the attachments folder; the task page lists them.

**Acceptance Scenarios**:

1. **Given** files were added in the dialog, **When** the task is created, **Then** each file is in the task's
   attachments folder with its original name, and a pasted screenshot gets a name like `screenshot_20261024_1655.png`.
2. **Given** a file with the same name already exists there, **When** it is saved, **Then** the new file is saved as
   `<name>_v2.<ext>` (never overwrites).
3. **Given** one of three files fails to save (too large, disk error), **When** the task is created, **Then** the task
   still exists, the two other files are saved, and the dialog says which file was not saved and why, with a way to
   retry it from the task page. Nothing is lost silently.
4. **Given** a file larger than 50 MB, **When** it is added, **Then** it is refused before the task is created, with a
   clear message.
5. **Given** the person removes a file from the list before Create, **When** the task is created, **Then** that file is
   not saved.

---

### User Story 3 - Attach more files later, fast (Priority: P2)

On the task page, an **Attach** button (next to today's "+ Save a file or script") saves straight into the task's
attachments folder: drop, choose or paste (Ctrl+V) a screenshot, optionally pick a sub-folder (Problem / Expected /
new). The existing save-destination panel stays as it is for scripts and deployment files.

**Why this priority**: during a fix the business sends more screenshots and samples; adding them must take seconds.

**Independent Test**: on an existing task, paste a screenshot and drop a PDF via Attach; both appear in the attachments
folder and in the task's files list without reloading the page.

**Acceptance Scenarios**:

1. **Given** a task page, **When** the person pastes an image while the Attach area is open, **Then** it is saved as a
   screenshot in the attachments folder and listed.
2. **Given** an archived (closed) task, **When** the person attaches a file, **Then** it is saved in the archived task's
   folder (same rule as today's save panel).

---

### User Story 4 - Same intake from the terminal and from agents (Priority: P2)

`New-SnTask` in the terminal menu asks the same branching questions (choice by number, multi-line answers, skip
questions that do not apply) and accepts file paths for attachments. The `ebs-task` skill asks New/Fix for reports and
the fix questions, so a task created by an agent has the same shape as one created in the dashboard.

**Why this priority**: the owner also creates tasks through Claude Code / Codex; a second, different intake would split
the data.

**Independent Test**: create a Report fix from the terminal without the dashboard; the task.json matches one created in
the dashboard with the same answers.

**Acceptance Scenarios**:

1. **Given** the terminal, **When** Report is chosen, **Then** the New/Fix choice is asked first and only the matching
   questions follow.
2. **Given** `New-SnTask -NonInteractive -Details @{ mode = 'Fix'; ... } -Attach <paths>`, **When** it runs, **Then**
   the files are copied into the attachments folder (originals untouched) and recorded on the task.

---

### User Story 5 - See image attachments on the task page (Priority: P3)

Image attachments (png, jpg, gif, webp) show as small previews in the task's files list, grouped Problem / Expected /
other; a click opens the full image. Other files keep Open / Show in folder.

**Why this priority**: helpful, not required to do the work; the files are already one click away.

**Independent Test**: a task with a Problem screenshot shows its preview; a click opens it.

**Acceptance Scenarios**:

1. **Given** an image attachment, **When** the task page opens, **Then** a preview shows and only files inside the work
   folder can be shown this way.

### Edge Cases

- A Report task created before this feature (no New/Fix answer): shows and works as today; no migration.
- The person has customised task types in Settings (stored in `overrides.json`): the new Report questions from the
  pack are not visible until the owner chooses to take them (see Assumptions and plan R5); saving Settings must never
  strip the new question fields (choices, conditions, file questions) from a type.
- Pasted image with no name, file names with Arabic letters or spaces, names with characters Windows forbids: saved
  with a safe name, Arabic kept.
- Many files at once (e.g. 20 screenshots): all saved, progress shown, one failure does not stop the others.
- The attachments setting points outside the task folder or outside the work folder: refused by validation.
- The task is closed (moved to `99_Archive`) while the dialog is open: the save fails with a clear message.
- A pack without an attachments setting: files go to `<task folder>\Attachments`.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The New task dialog MUST offer an attachments area for every task type (drop, choose, paste image) and
  save the files into the task's attachments folder after the task is created.
- **FR-002**: The attachments folder MUST be defined by the career pack as a pattern inside the task folder; if the pack
  has none, it MUST default to `<task folder>\Attachments`; it MUST be refused if it resolves outside the work folder.
- **FR-003**: Saving an attachment MUST never overwrite an existing file (`_v2`, `_v3` ...), MUST keep the original file
  name (unsafe characters replaced), and MUST record the file on the task (time, relative path, which question it
  belongs to) and in `_NOTES.md`.
- **FR-004**: Task-type intake questions MUST support, as pack data: a choice list (`options`), a multi-line answer,
  a file question (with an optional sub-folder), a required flag, and a condition that shows the question only when
  another answer has a given value. Existing questions without these fields MUST behave exactly as today.
- **FR-005**: A task type MUST be able to define variants (e.g. Fix) chosen by an answer; a variant replaces the type's
  open questions, checklist and object names for that task. Without a matching variant, the type's own lists apply.
- **FR-006**: Questions hidden by a condition MUST NOT be saved on the task. Blank answers to questions the pack marks
  as "ask the business if blank" MUST become open questions on the task.
- **FR-007**: The Oracle EBS technical pack MUST define for Report: the New/Fix choice, today's questions as the New
  branch, the fix questions listed in User Story 1 (report type as a choice list of EBS report types), the two file
  questions, and a Fix variant with its own open questions, checklist and object names. The Oracle EBS functional pack
  MUST get the same New/Fix branch, worded for a functional consultant.
- **FR-008**: The engine and the page MUST contain no EBS words for this feature; all wording, report types and folder
  names come from the pack (Principle I). Other packs MAY use the same fields later without code changes.
- **FR-009**: The task page MUST offer a quick Attach action that saves into the attachments folder (with optional
  sub-folder), including pasted screenshots; today's save-destination panel MUST keep working unchanged.
- **FR-010**: Files over 50 MB MUST be refused before anything is written; a failed file MUST be reported by name and
  reason and MUST NOT stop the other files or undo the created task.
- **FR-011**: The terminal `New-SnTask` MUST ask the same branching questions and accept attachment paths; the
  `ebs-task` skill MUST ask the same report intake.
- **FR-012**: The Settings task-type editor MUST keep the new question fields and variants when the person saves
  (no silent loss).
- **FR-013**: Image attachments MAY show as previews on the task page; only files under the work folder may be served.
- **FR-014**: All writes MUST go through the local server with the existing write header; nothing is uploaded anywhere
  (Principle III). Attachments MUST NOT be copied into the product repository.

### Key Entities

- **Intake question** (pack data, per task type): key, label, default, kind (text, long text, choice, files), options,
  required, condition (show when key = value), ask-business-if-blank flag, sub-folder for file questions.
- **Task-type variant** (pack data): condition (key = value), open questions, checklist, object names that replace the
  type's own lists.
- **Attachment** (on the task): time, relative path in the work folder, which question it belongs to (or general),
  original name. Stored in the task's existing `files` list (additive fields only).
- **Attachments place** (settings / pack): pattern inside the task folder, default `{ticket}\Attachments`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A Report fix task with all fix answers and 3 attachments can be created in under 3 minutes, in one dialog.
- **SC-002**: 100% of attachments added in the dialog end up in the task's attachments folder or are reported by name
  as not saved; none is lost silently.
- **SC-003**: A fix task created with blank parameters shows that gap as an open question on the task page, every time.
- **SC-004**: Creating any non-report task, or a new report, gives the same task as before the feature (same fields,
  checklist, open questions), checked by tests.
- **SC-005**: Adding one more screenshot to an existing task takes under 10 seconds (open task, paste, done).
- **SC-006**: Saving Settings 5 times in a row keeps every choice list, condition and file question of the Report type.

## Assumptions

- "New or fix" applies to the **Report** type in both EBS packs now; the fields are generic, so Interface, Extension,
  etc. can get a Fix branch later by editing the pack only (owner can widen it, see question Q1 in the hand-over).
- "Change an existing report" (add a column, new parameter) uses the Fix branch; the "correction needed" question
  covers it. A third choice can be added in the pack later.
- Attachments for EBS packs go to `01_Requirements\Attachments` (with `Problem` / `Expected` for fix files) because
  they are requirement input; scripts keep their current destinations (Q2).
- Fix answers are stored in the task's existing details list (question + answer), so the task page, `_NOTES.md`,
  knowledge capture and the CV flow read them with no new reader. Editing details after creation is out of scope.
- The 50 MB limit is the one the save panel already uses.
- Live data: the live install's `overrides.json` may already hold its own copy of task types. Taking the new pack
  questions into the live install is a step of the live upgrade and needs the owner's word (plan R5); this spec does
  not change live data.
- Build order with Phase A (write safety, board P4): this feature touches `New-SnTask` and `Save-SnFile`, which Phase A
  also converts. Default: build AT1-AT5 on main now with small, separate changes, and let P4 take them in when it is
  forward-ported (Q3).

## Out of scope

- Editing intake answers after the task is created; deleting or renaming attachments from the dashboard (Explorer
  does it); OCR or reading text from screenshots; sending attachments by email; AI analysis of the problem screenshot.
