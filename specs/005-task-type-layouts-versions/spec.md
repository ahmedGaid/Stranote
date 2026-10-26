# Feature Specification: Task-type layouts, Data request type and file versions

**Feature Branch**: `claude/TL0` (spec, stacked on spec 004 `claude/AT5`); build rows TL1-TL6

**Created**: 2026-10-26

**Status**: Draft - waits for owner approval before TL1

**Input**: Owner request (2026-10-26): "I need to update tasks to add a task where a consultant just asked me for
getting data from the DB by SQL query, and I need the task checklist and folder structure to change according to the
task type. For example if it's just a script for data I need folders like a folder for scripts and versions and a
folder for data sheets with versions also, and if the user sent a script or screenshots to me for help I need to save
them in a separate folder also, and when I paste or upload any files I need the app to ask me if it's new or another
version of an existing one, and so on."

## What exists today (baseline, after spec 004)

- Every task gets the **same sub-folders** (`settings.ticketFolders`, EBS technical: `01_Requirements`, `02_Design`,
  `03_Dev`, `04_Test`, `05_Deploy`) and the **same base checklist** (9 items from MD050 to "Deployed to PROD") plus the
  common open questions ("Who signs off UAT?", "Target PROD date?"), whatever the task type. A one-hour data request
  gets a full development project layout.
- A task type adds its own questions, open questions, checklist items and object names on top (spec 004 added choice
  questions, conditions, file questions and variants).
- There is no "Data request" type. The closest, **Analysis**, asks "what question must be answered" only.
- Files are saved through **"+ Save a file or script"** (pack save targets) or **Attach** (attachments folder, spec 004).
  If a file with the same name exists, the new one silently becomes `<name>_v2`. The app never asks whether a file is a
  new file or a new version of one already there, and the task page does not show versions together.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A "Data request" task gets its own folders and checklist (Priority: P1)

A consultant asks the person for data ("give me all AP invoices on hold for OU X since July"). The person creates a task
of type **Data request**. The dialog asks the data-request questions:

1. What data is needed and why (the business question) - long text, required
2. Instance to query (PROD / UAT / DEV ...)
3. Operating unit / ledger / organization
4. Filters and parameters (period, dates, statuses ...) - long text; blank -> open question
5. Columns needed (or attach their sample sheet) - long text; blank -> open question
6. Output wanted - choice: Excel sheet, CSV file, In the email body / screenshot, SQL only (they run it)
7. One time or recurring - choice: One time, Recurring (may become a report)
8. Their script / screenshots / sample sheet - file drop area (saved in the requester folder)

The task is created with **its own layout** instead of the general one:

```text
01_Tickets\T-0050_AP_DataRequest_Invoices_on_hold\
  _NOTES.md  task.json
  01_From_Requester\     their scripts, screenshots, sample sheets, emails
  02_Scripts\            my queries, versioned (..._v1.sql, ..._v2.sql)
  03_Data\               data sheets I send, versioned (..._v1.xlsx, ..._v2.xlsx)
```

and **its own checklist only** (no MD050 / UAT / PROD deployment items):

- Need, filters and columns confirmed with the requester
- Query written and run on the agreed instance
- Row count and totals checked against the application screens or a known figure
- Data sheet saved in 03_Data and sent to the requester
- Requester confirmed the data is right
- Reusable query saved as a snippet (if it will be needed again)

Its open questions are about the data, not about a deployment: "Is querying PROD allowed, or should it run on a
clone?", "Does the data contain personal or sensitive fields that must be masked or left out?", and "Will this be
needed again (should it become a report)?" when "Recurring" is chosen.

**Why this priority**: data requests are frequent, short and today they are either not tracked or tracked with a
misleading 9-step development checklist and five empty folders.

**Independent Test**: create a Data request with filters left blank and one dropped screenshot; the task folder has
exactly the three sub-folders, the screenshot is in `01_From_Requester`, the checklist has the six data items and none
of the base items, and "Which filters / date range?" is an open question.

**Acceptance Scenarios**:

1. **Given** the New task dialog, **When** the person picks Data request, **Then** the data-request questions show and
   the attachments area says the files go to the requester folder.
2. **Given** a created Data request, **When** its folder is opened, **Then** it has only the type's sub-folders (no
   `02_Design`, `05_Deploy` ...).
3. **Given** a created Data request, **When** its checklist shows, **Then** it has the type's items only, not the
   pack's base checklist, and the common deployment questions are not added.
4. **Given** any other task type that defines no layout (Report, Interface ...), **When** it is created, **Then** folders,
   checklist and questions are exactly as before this feature.

---

### User Story 2 - "New file or new version?" on every save (Priority: P1)

Whenever the person saves a file into a task - Attach (drop, choose, paste a screenshot), "+ Save a file or script"
(upload or pasted script text) - and the destination folder already holds files, the app asks **before saving**:

- **New file** - with a name box (default: the file's own name), or
- **New version of** one of the files already there, shown as a short list of file families with their latest version
  ("AP_holds_query - v2, 26 Oct 10:15"), with the most likely one pre-selected (same file type, closest name), plus an
  optional one-line **"What changed"** note.

A new version is saved under the family's name with the next number (`AP_holds_query_v3.sql`) even if the uploaded file
was called `Book1.xlsx`; the earlier versions stay untouched. In a versioned place (Scripts, Data) the first file of a
family already gets `_v1`, so the version is visible in the name when the sheet is emailed.

**Why this priority**: the owner sends a data sheet, gets "please add the supplier site", and sends v2, v3 ... today
those versions get random names or overwrite-avoiding `_v2` suffixes, and it is unclear which one was sent.

**Independent Test**: on a Data request with `AP_holds_v1.xlsx` in 03_Data, save `Book1.xlsx` as a new version with
note "added supplier site": the folder holds `AP_holds_v1.xlsx` and `AP_holds_v2.xlsx`, the task page shows v2 as the
latest with v1 under "older versions", and `_NOTES.md` logs the note.

**Acceptance Scenarios**:

1. **Given** an empty destination folder, **When** the person saves a file, **Then** no question is asked (it is a new
   file; in a versioned place it gets `_v1`).
2. **Given** a folder with files, **When** the person saves one, **Then** the New / New version question shows and
   nothing is written until they answer; Cancel writes nothing.
3. **Given** "New version of AP_holds" when v1 and v2 exist, **When** saved, **Then** the file is `AP_holds_v3.<ext of
   the new file>`, and v1, v2 are unchanged.
4. **Given** "New file" with a name that already exists, **When** saved, **Then** the app says so and offers "save as new
   version" or "change the name"; it never overwrites.
5. **Given** five screenshots dropped at once, **When** the question shows, **Then** one answer can apply to all
   ("all new files") or each file can be answered on its own.
6. **Given** a pasted script text (not a file), **When** saved, **Then** the same question is asked, with the name box
   for a new file.
7. **Given** a file family whose earlier versions were saved before this feature (`query.sql`, `query_v2.sql`),
   **When** listed, **Then** they are recognised as one family (v1 = the plain name).

---

### User Story 3 - Files from the requester always go to their own folder (Priority: P1)

Scripts, screenshots, sample sheets or emails that the requester sent for help are saved in the type's requester
folder (Data request: `01_From_Requester`), apart from the person's own work. In the New task dialog and on the task page
the attachments area accepts files, pasted screenshots **and pasted text** (their script copied from an email or
chat), saved as a file whose name the person confirms (`requester_script.sql` when it looks like SQL, else `.txt`).

**Why this priority**: the owner asked for it explicitly; mixing "their query" and "my query" in one folder loses which
one was sent back.

**Independent Test**: paste a SQL text into the attachments area of a new Data request; after create, it is
`01_From_Requester\requester_script.sql` and the task page lists it under "From requester".

**Acceptance Scenarios**:

1. **Given** a type with its own attachments folder, **When** files are attached, **Then** they go there; types without
   one keep the spec 004 place (`01_Requirements\Attachments` for EBS).
2. **Given** pasted text in the attachments area, **When** the task is created, **Then** it is saved as a UTF-8 file
   (Arabic kept) and listed like any attachment.

---

### User Story 4 - The person can shape any task type in Settings (Priority: P2)

In Settings > Task types each type gets a **Layout** part: its own sub-folders (with a live folder preview, as the
general ticket folders have today), its save places with a "versioned" switch, its attachments (requester) folder,
"Also add the general checklist" and "Also add the general open questions" switches. A type with no layout uses the
general ones, as today. Saving Settings keeps every field.

**Why this priority**: the owner said "and so on": Support, Analysis or Setup may need lighter layouts later; this must
be a settings change, not a code change (Principle I).

**Independent Test**: give Support its own folders `01_Evidence`, `02_Fix` and turn off the general checklist; a new
Support task has those two folders and only the Support checklist; an old Support task is unchanged.

**Acceptance Scenarios**:

1. **Given** a type layout edited and saved, **When** Settings is saved five times, **Then** the layout is still complete.
2. **Given** a folder name that is not a safe relative folder (`..\x`, `C:\x`), **When** saved, **Then** it is refused
   with a clear message.
3. **Given** a layout change, **When** existing tasks of that type are opened, **Then** their folders and checklists are
   not changed (only new tasks use the new layout).

---

### User Story 5 - Same layout and versions from the terminal and from agents (Priority: P2)

`New-SnTask` creates the type's layout; `Save-SnFile` accepts "new version of <family>" with a note, and lists the
families of a place. The `ebs-task` skill knows Data request, and `ebs-dashboard-guide` tells where each deliverable of
a data request goes (query -> Scripts as the next version, sheet -> Data as the next version, requester material ->
From requester), so a query Claude writes lands as `..._v2.sql` next to `..._v1.sql`.

**Why this priority**: the owner often has the agent write the SQL; agent saves must follow the same rules.

**Independent Test**: from the terminal, save a query twice as versions of one family; the files are `_v1`, `_v2` and
the task records both.

**Acceptance Scenarios**:

1. **Given** an agent saves a query for a Data request whose Scripts folder already has `AP_holds_v1.sql`, **When** it
   follows the guide, **Then** it saves `AP_holds_v2.sql` with a "what changed" note, never overwriting v1.

---

### User Story 6 - See versions together on the task page (Priority: P3)

The task's files list groups files by place (From requester, Scripts, Data ...) and by family: the latest version shows
first with its note and time; older versions fold under "older versions (n)". Open and Show in folder work for each.

**Why this priority**: helpful for answering "which version did I send?"; the files are already in Explorer.

**Independent Test**: a family with three versions shows one row (v3) with "older versions (2)".

---

### User Story 7 - A Data request moves through its own short phases (Priority: P2)

A Data request does not go through Design, UAT or Deployment. Its phases are its own:

`Requested -> Query written -> Data sent -> Confirmed -> Done` (plus `On Hold`)

The task page, the update dialog and the terminal offer only the task type's phases. Each type phase belongs to one
column of the general board (Requested -> Requirements, Query written -> Development, Data sent and Confirmed -> UAT,
On Hold -> On Hold, Done -> Done), so the board keeps one set of columns for all tasks; the card shows the task's own
phase name ("Data sent") inside that column. Each phase can set the progress percent, as general phases do today.

**Why this priority**: owner choice (2026-10-26, option B): the general phases do not describe a data request, and
skipping four meaningless phases on every request is noise.

**Independent Test**: create a Data request; the update dialog offers only its 5 phases + On Hold; set "Data sent";
the card shows in the UAT column with the label "Data sent" and 70%; a Report task still offers the general phases.

**Acceptance Scenarios**:

1. **Given** a Data request, **When** the person opens the update dialog, **Then** the phase list is the type's list,
   not the general one.
2. **Given** a type phase with a board column, **When** the board shows, **Then** the card is in that column and shows
   its own phase name.
3. **Given** a type without its own phases, **When** it is updated, **Then** the general phases show, as today.
4. **Given** a type's phases are changed in Settings and an old task is in a phase that no longer exists, **When** it is
   shown, **Then** it keeps its phase (shown as today's "extra" column) and the update dialog still offers it, so
   nothing is lost.
5. **Given** a task is closed, **When** it is archived, **Then** its phase is `Done`, as for every task today.

### Edge Cases

- Tasks created before this feature: keep their folders and checklist; the version question and family grouping work on
  their existing files (plain name = v1, `_v2`, `_v3` = later versions).
- A family name that itself ends in `_v<n>` (a requester's `report_v7.xlsx`): saved as new file it keeps its name; the
  family is `report` with v7 detected; a new version is v8. Documented, not an error.
- A version with a different file type (v1 `.sql`, v2 `.txt`): allowed; the family is the name without extension.
- Two people/agents saving a version at the same moment: the second gets the next free number; never overwrites.
- A type layout whose folders do not include the folder of a save place: the folder is created on first save.
- Settings `overrides.json` already holds its own copy of task types (migrated live install): the new Data request type
  is not visible until the owner chooses to take it (live upgrade step, owner's word, backup first - as spec 004 R5).
- A type changes from "no layout" to a layout while its tasks are open: only new tasks use it.
- Very many files in one place (200 screenshots): the question lists families, not single files, and stays usable.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A task type MUST be able to define, as pack data, its own task sub-folders; when it does, new tasks of
  that type get those folders instead of the general ticket folders. Types without them MUST behave as today.
- **FR-002**: A task type MUST be able to turn off the general checklist and the general open questions for its tasks;
  default is "on" (today's behaviour).
- **FR-003**: A task type MUST be able to define its own save places (name, folder inside the task, versioned yes/no);
  its task page then shows those places plus the pack's places that are outside the task folder (Git repo, snippets).
- **FR-004**: A task type MUST be able to define its own attachments (requester) folder inside the task folder; without
  one the spec 004 attachments place applies.
- **FR-005**: The Oracle EBS technical pack MUST add a **Data request** type with the questions, layout
  (`01_From_Requester`, `02_Scripts` versioned, `03_Data` versioned), checklist and open questions of User Story 1, with
  the general checklist and general open questions turned off.
- **FR-006**: Before any save into a folder that already holds files, the dashboard MUST ask "new file" or "new version
  of <family>" (families listed with latest version and time, best guess pre-selected, optional "what changed" note);
  nothing is written until answered; Cancel writes nothing.
- **FR-007**: A new version MUST be saved as `<family>_v<next>.<ext>`, where next = highest existing version + 1; files
  MUST never be overwritten; a plain name without `_v<n>` counts as version 1. In a versioned place the first file of a
  family MUST be saved as `<name>_v1.<ext>`.
- **FR-008**: The task MUST record for each saved file its family, version, the file it follows (if any) and the note;
  `_NOTES.md` MUST log "version n of <family>" and the note.
- **FR-009**: The attachments area (New task dialog and task page) MUST accept pasted text and save it as a UTF-8 file
  with a confirmed name.
- **FR-010**: The Settings task-type editor MUST edit every layout field (folders with preview, save places with
  versioned switch, attachments folder, the two switches) and MUST keep all fields on save; every folder MUST pass the
  safe-relative-folder check and stay inside the task folder.
- **FR-011**: Changing a type's layout MUST NOT change folders, checklists or files of existing tasks.
- **FR-012**: `New-SnTask` and `Save-SnFile` (terminal, agents) MUST apply the same layout and version rules; the
  `ebs-task` and `ebs-dashboard-guide` skills MUST describe the Data request type and its save places.
- **FR-013**: The task page SHOULD group files by place and family, latest version first, older versions folded.
- **FR-014**: Engine and page MUST contain no EBS words for this feature; type names, folders and wording come from the
  pack (Principle I). All writes go through the local server with the existing write header; nothing leaves the PC.
- **FR-015**: A task type MUST be able to define its own phases (name, optional percent, the general board column it
  shows in); the list MUST include `Done` and MAY include `On Hold` (same meaning as the general ones). Without it, the
  general phases apply.
- **FR-016**: The update dialog, the task page and the terminal MUST offer the task type's phases; the board MUST keep
  the general columns, place each card in its phase's column and show the task's own phase name on the card.
- **FR-017**: The Data request type MUST use the phases of User Story 7 (Requested 10%, Query written 40%, Data sent
  70%, Confirmed 90%, On Hold, Done).
- **FR-018**: Changing a type's phases MUST NOT change the phase of existing tasks; a task whose phase is no longer in
  the list keeps it and can still be updated.

### Key Entities

- **Type layout** (pack data, per task type): sub-folders, save places, attachments folder, use-general-checklist,
  use-general-questions, phases. Absent = today's general settings.
- **Type phase**: name, percent, board column (a general phase name).
- **Save place** (general or per type): name, folder pattern, prefix flag (today), versioned flag (new).
- **File family**: files in one place sharing a name without the `_v<n>` ending and extension; has versions 1..n.
- **Saved file record** (on the task, additive): today's time, path, place; new family, version, follows, note.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A Data request with one requester screenshot can be created in under 90 seconds, and its folder holds only
  the three data folders.
- **SC-002**: 100% of saves into a non-empty folder ask New / New version first; 0 files are ever overwritten (tests).
- **SC-003**: Saving a third version of a data sheet takes under 15 seconds (open task, drop file, accept the
  pre-selected family, save).
- **SC-004**: Creating any type without a layout gives the same task as before the feature (same folders, checklist,
  open questions), checked by tests.
- **SC-005**: Saving Settings 5 times keeps every layout field of every type.
- **SC-006**: Existing files named `x.sql`, `x_v2.sql` are listed as one family with 2 versions.
- **SC-007**: A Data request goes from created to Done in 4 phase changes or fewer, and never shows Design, UAT or
  Deployment as a choice.

## Assumptions

- Owner answers (2026-10-26): **Q1** "any one" -> versions stay in the same folder with `_v<n>` in the name (visible in
  Explorer and in the emailed file name; no renames). **Q2** "any one" -> Data request is added to the **EBS
  technical** pack only; the functional pack and other packs can add it later by pack data only. **Q3** "b" -> types
  can have their own phases; Data request gets its own (User Story 7). Other EBS types keep today's layout and
  phases; the owner can give Support / Analysis lighter layouts or phases in Settings.
- The version question is asked by the dashboard; terminal and agents state the choice with a parameter (no prompt
  when a parameter is given). The best guess uses file type and name similarity only; no content comparison.
- Builds on spec 004 (attachments, intake fields, type editor pass-through); TL1 starts after AT0-AT5 are merged and
  this spec is approved. Phase A (P4) also converts `New-SnTask` and `Save-SnFile`; same rule as spec 004: small,
  separate changes, P4 takes them in when forward-ported.
- Live data: taking the new type into the live install's `overrides.json` (if it holds its own `types`) is a live
  upgrade step that needs the owner's word and a backup.

## Out of scope

- Running SQL from the app or connecting to any database; a separate board (own columns) per task type; moving or renaming files of existing tasks;
  deleting versions from the dashboard; comparing the content of two versions (diff); sending data sheets by email;
  masking data automatically.
