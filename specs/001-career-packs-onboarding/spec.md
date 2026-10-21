# Feature Specification: Career packs and first-day onboarding

**Feature Branch**: `001-career-packs-onboarding`

**Created**: 2026-10-19

**Status**: Draft

**Input**: User description: "Convert Ops into a tool that any career can use to build their own knowledge from
their daily work in any field. On first use the person chooses their field, career and level, and Ops asks them
configuration questions (for example, as an Oracle EBS technical consultant on day one of a new job)."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Existing Oracle EBS user keeps everything (Priority: P1)

Today Ops is built for one person: an Oracle EBS technical consultant. Everything EBS-specific (modules, task
types and their intake questions, checklists, folders, save destinations, the rules that find APIs and tables in
scripts, categories) moves out of the code into an "Oracle EBS Technical" career pack. The current user opens Ops
after the upgrade and sees exactly what they saw before: same tasks, cards, questions, review schedule, streak,
lessons, settings and folders.

**Why this priority**: Everything else depends on the engine reading career knowledge from a pack. It must not
cost the only real user any data or habit (Constitution IV).

**Independent Test**: Take a copy of the current `D:\Work` data, run the upgrade, and compare tasks, cards,
questions (box, due, history), concept statuses, review log, settings and the rendered dashboard before and after.

**Acceptance Scenarios**:

1. **Given** the current EBS data, **When** Ops starts after the upgrade, **Then** a profile is created that points
   to the "oracle-ebs-technical" pack, a backup of settings and learning data exists, and nothing is lost or
   duplicated.
2. **Given** the upgraded app, **When** the user creates a "Report" task, **Then** they get the same intake
   questions, checklist, folders and object names as before.
3. **Given** a saved script that calls `FND_PROGRAM.ADD_TO_GROUP`, **When** knowledge syncs, **Then** the same
   automatic API card and flash question appear as before (same IDs, progress kept).

---

### User Story 2 - First-day onboarding for a new user (Priority: P1)

A new user opens Ops for the first time. A short wizard (about 5 minutes) asks: preferred explanation language and
learning style; field, role and level; a self-rating per area of their role; the job (company, start date,
industry, working days and hours, systems and versions, naming conventions, ticket system and ID format,
environments, source control); how work arrives (task types, phases, work folder); learning goals (3-month focus,
target certification or role, daily minutes, review time); privacy (what never leaves the machine, what never
appears on the CV); and optionally a pasted CV. From the answers Ops builds the settings, folders, concept levels,
review schedule and a first-week learning plan, then shows the board with the first task prompt.

**Why this priority**: This is the entry point for every career. Without it, a new user faces an empty, EBS-shaped
app.

**Independent Test**: With an empty data folder, complete the wizard as "Oracle EBS Technical Consultant, mid
level" and as "ICU nurse, junior"; check the generated profile, folders, task types, concept statuses, review time
and first-week plan for each.

**Acceptance Scenarios**:

1. **Given** no profile exists, **When** Ops opens, **Then** the onboarding wizard opens instead of the board.
2. **Given** the user rates "PL/SQL" as expert and "OAF" as new, **When** onboarding finishes, **Then** PL/SQL
   concepts are marked `known` (their questions are quiz-ready without a lesson) and OAF concepts are `new` (lessons
   first), and the first-week plan contains OAF lessons but no PL/SQL lessons.
3. **Given** the user chose Egyptian Arabic, **When** a lesson or explanation opens, **Then** it is in Egyptian
   Arabic with technical terms in English.
4. **Given** working days Sun-Thu and review time 09:00, **When** onboarding finishes, **Then** the morning review
   is scheduled for 09:00 and Fri/Sat do not break the streak.
5. **Given** the user leaves the wizard halfway, **When** they reopen Ops, **Then** the wizard resumes where they
   stopped.
6. **Given** a finished onboarding, **When** the user opens Settings, **Then** every answer can be changed there and
   "Run onboarding again" is available without losing data.

---

### User Story 3 - Ready packs for other careers (Priority: P2)

Ops ships with more packs so the idea is proven beyond EBS: Oracle EBS Functional (Financials), Accountant,
Software Developer and Nurse. Each pack has areas, task types with intake questions and checklists, folders,
knowledge extractors, starter lessons for day one and a skill map by level.

**Why this priority**: Shows the engine is truly career-agnostic (Constitution I) and gives non-EBS users a useful
day one.

**Independent Test**: For each pack, onboard a test user, create one task of each type, save a sample work file,
and confirm cards, a starter lesson and quiz-ready questions appear after the lesson.

**Acceptance Scenarios**:

1. **Given** the Accountant pack, **When** the user saves month-end notes mentioning "accrual" and "IFRS 15",
   **Then** knowledge cards are created for those terms under the right area.
2. **Given** any shipped pack, **When** it is loaded, **Then** it passes schema validation.

---

### User Story 4 - A pack for any other career (Priority: P3)

If the user's career is not in the list, the wizard saves their answers as a pack request. In a Claude session the
user says "build my Ops pack"; Claude drafts a pack from the answers (areas, task types, questions, checklists,
extractors, starter lessons), validates it, and the user reviews and accepts it in Ops.

**Why this priority**: Covers the long tail of careers without hand-writing packs, but needs the earlier stories.

**Independent Test**: Onboard as "Civil site engineer", choose "My career is not listed", ask Claude to build the
pack, accept it, and create a first task with it.

**Acceptance Scenarios**:

1. **Given** an unlisted career, **When** the wizard finishes, **Then** a general starter pack is used until the
   drafted pack is accepted, and the pending request is visible in Settings.
2. **Given** a drafted pack that fails validation, **When** the user tries to accept it, **Then** Ops shows what is
   wrong and keeps the current pack.

---

### User Story 5 - Switching or combining roles (Priority: P3)

A person changes jobs (for example from EBS Technical to Fusion Financials) or does two roles. They can add a second
pack to their profile; past tasks and knowledge stay with the pack and company they belong to, and the career
counter, skills and CV keep the full history.

**Why this priority**: Real careers change; the knowledge built must not be stranded.

**Independent Test**: Add a second pack and a new company; confirm old cards keep their areas and new tasks use the
new pack's task types.

**Acceptance Scenarios**:

1. **Given** two packs on the profile, **When** the user creates a task, **Then** they choose which role it belongs
   to (default: the current company's role).

### Edge Cases

- A pack update renames or removes an area that existing cards use: cards keep their stored area and show it as
  "archived area" instead of disappearing.
- A pack and the user's own setting disagree (for example the user renamed a task type): the user's change wins and
  survives pack updates.
- A pasted CV contains a client name: it is used only to rate skills and is never copied to CV bullets.
- Onboarding chooses a work folder that already has files: nothing is overwritten; only missing folders are created.
- Two onboarding runs on the same machine (re-onboarding): existing data is kept; only answers and plan change.
- The chosen language has no ready lesson text: lessons show the original text with a note and a "translate with
  Claude" follow-up request.
- A pack's extractor pattern is invalid or too slow: it is rejected at validation, not at run time.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST load all career-specific configuration from a career pack file (areas, categories,
  task types with intake questions, checklists and object patterns, folders, save destinations, knowledge
  extractors, starter lessons, skill map, vocabulary/abbreviations).
- **FR-002**: The system MUST validate every pack against a versioned schema on load and refuse invalid packs with
  a message naming the field.
- **FR-003**: The system MUST migrate the current EBS installation to a profile using the "oracle-ebs-technical"
  pack without losing or altering existing tasks, cards, questions, progress, concept statuses, review history or
  user settings, after taking a backup.
- **FR-004**: The system MUST show an onboarding wizard on first run (no profile) and resume a partly finished
  wizard.
- **FR-005**: The wizard MUST collect: explanation language and style; field, role, level and years; a self-rating
  (new / basic / comfortable / expert) per pack area; company, start date, industry, working days and hours;
  systems and versions, naming prefix, ticket system and ID format, environments, source control (each optional
  and shown only if the pack asks for it); task types and phases (pre-filled from the pack); work folder; learning
  goals, target certification or role, daily minutes and review time; privacy rules; optional pasted CV.
- **FR-006**: From the answers the system MUST generate: the profile, settings (merged with pack defaults), the work
  folder structure (create missing folders only), concept statuses from self-ratings, the career entry (company,
  role, start date, weekend), the daily review schedule, and a first-week plan of starter lessons for areas rated
  new or basic and listed in the learning goals.
- **FR-007**: Areas rated expert MUST mark their concepts `known`; areas rated new MUST require a lesson before
  their questions are quiz-ready (Constitution II).
- **FR-008**: The system MUST ship at least five packs: Oracle EBS Technical, Oracle EBS Functional (Financials),
  Accountant, Software Developer, Nurse; plus a minimal General pack used for unlisted careers.
- **FR-009**: Knowledge extraction MUST use the extractors declared in the active pack; extractor output MUST keep
  the deterministic card and question IDs used today for EBS (so progress is kept).
- **FR-010**: Users MUST be able to change any onboarding answer later in Settings and re-run onboarding without
  data loss.
- **FR-011**: For an unlisted career the system MUST save a pack request (the onboarding answers) that a Claude
  skill can turn into a draft pack; the user MUST be able to review, accept or reject the draft in Ops.
- **FR-012**: User overrides (renamed task types, edited questions, extra folders) MUST be stored separately from
  the pack and survive pack updates.
- **FR-013**: A profile MUST support more than one pack (role), each linked to the companies where it applies.
- **FR-014**: CV generation MUST apply the privacy answers (never client names, ticket IDs, or the internal naming
  prefix) for every pack.
- **FR-015**: The wizard and all generated text MUST appear in the chosen interface language (English at least;
  Arabic labels for learning text), with technical terms kept as-is.

### Key Entities

- **Career Pack**: A named, versioned bundle for one role: id, name, field, levels, areas (with concepts and
  categories), task types (intake questions, checklist, phases, object patterns), folders and save destinations,
  extractors, starter lessons, skill map, vocabulary, onboarding questions specific to the role.
- **Profile**: The person: language and learning style, roles (pack id + level + years), self-ratings per area,
  learning goals, daily minutes, review time, privacy rules, onboarding state.
- **Role Assignment**: Links a pack to companies and dates; tasks and knowledge carry the role they belong to.
- **Onboarding Answers**: The raw answers, kept so onboarding can be resumed, re-run or sent as a pack request.
- **Pack Request**: Answers for an unlisted career, waiting for a drafted pack.
- **User Overrides**: The person's changes on top of a pack.
- **First-Week Plan**: Ordered starter lessons with target days, derived from ratings and goals.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new user finishes onboarding in under 7 minutes and sees their first lesson within 10 minutes of
  opening Ops.
- **SC-002**: After the upgrade, 100% of the current user's tasks, cards, questions (with box, due and history),
  concept statuses and review history are identical to before.
- **SC-003**: A new career can be added by writing one pack file, with zero code changes.
- **SC-004**: For each shipped pack, a scripted test user gets at least 10 knowledge cards from 5 sample work files.
- **SC-005**: Users never see a quiz question on an area they rated "new" before its lesson (0 violations in tests).
- **SC-006**: In a usability check, 4 of 5 people from different careers say the first-week plan matches their real
  gaps.

## Assumptions

- Ops stays a local Windows app on the current stack for this feature; packaging as an installable product,
  sync, accounts and payments are separate later features.
- There is no built-in live AI in Ops yet; drafting packs for unlisted careers and writing richer lessons happen
  through Claude sessions using the Ops skills (the person's own Claude account), never through keys in the app.
- The person runs Ops on their own machine; their work data never goes into the product repository.
- The interface stays English with Arabic learning text; full UI translation is a later feature.
- The existing Claude skills (task recording, dashboard guide, stranote-learn) will be generalized to read the active
  pack (T046). Project progress is tracked with the `/ops_resume` + `/ops_status` pair, not inside Ops.
