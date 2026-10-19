<!--
Sync Impact Report
- Version: (template) -> 1.0.0  (first ratification)
- Principles added: I-VII (all new)
- Sections added: Technical Constraints, Development Workflow, Governance
- Templates checked: plan-template.md (Constitution Check reads these gates) OK; spec-template.md OK; tasks-template.md OK
- Follow-up TODOs: none
-->
# Stranote Constitution

Stranote turns a person's daily work, in any career, into lasting knowledge: it records the work, captures what was
learned, teaches it first, makes the person recall it on a spaced schedule, and turns it into skills and CV lines.

## Core Principles

### I. One engine, many careers (career knowledge is data, not code)
The engine (tasks, knowledge capture, lessons, daily review, visual cards, skills, CV) MUST NOT contain
career-specific logic. Everything that differs between careers (vocabulary, areas, task types, intake questions,
checklists, folder layout, save destinations, knowledge extractors, starter lessons, skill map) lives in a
**career pack** file. Adding a career MUST NOT require a code change.

### II. Teach before quiz (NON-NEGOTIABLE)
A person is never graded on something Stranote has not explained. A question becomes quiz-ready only after its concept
was taught and understood, the person said they already know it, or they practised it before. Explanations come
first (why / how / when, analogy, example from the person's own work), then a check of understanding, then
questions. Difficulty rises gradually; mistakes are corrected kindly and explained.

### III. Local-first and private
All work data (tasks, files, notes, screenshots, knowledge, progress) stays on the person's machine. The server
listens on localhost only and every write requires the `X-EBS: 1` header. No API keys or secrets in the frontend;
any AI call goes through a local or backend component the person controls. CV output MUST NOT contain employer or
client names, ticket IDs or internal object names. Stranote never asks for or stores the person's work-system passwords.

### IV. Never lose progress
Existing tasks, cards, questions, Leitner boxes, concept statuses, review history and settings MUST survive every
upgrade. Changes to stored data are additive or come with a tested, lossless migration and a backup taken first.
Existing workflows (dashboard, terminal menu, Claude skills) keep working unless a spec says otherwise.

### V. Learn in your own language
Explanations, lessons and quiz feedback are in the language the person chose during onboarding (for example
Egyptian Arabic), keeping technical terms, code and identifiers in their original form. RTL text is rendered with
Latin runs isolated.

### VI. Test the engine, see the UI
Engine logic (pack loading, onboarding output, migrations, readiness, spaced repetition, review picking) is covered
by Pester tests that run against a throw-away data folder (`STRANOTE_LEARN_DIR`), never real data. Every UI change is
verified in a browser with no console errors, in light and dark mode.

### VII. Simple until proven
Stay on the current stack (Windows PowerShell 5.1, a local HttpListener, one HTML template, JSON files) until a
spec explicitly decides to package Stranote as a product. No new runtime, framework or service without a written reason
in the plan's Complexity Tracking.

## Technical Constraints

- Windows PowerShell 5.1 compatible: no `&&`, `??`, ternary or PowerShell 7-only APIs; UTF-8 files without BOM.
- JSON for all data and packs (no YAML: there is no built-in parser in PowerShell 5.1).
- Pack files carry a `schemaVersion`; the loader validates them and rejects invalid packs with a clear message.
- Product source lives in `D:\Projects\Stranote`; personal work data lives in the person's work root (for example
  `D:\Work`) and is never copied into the product repository.
- Visual identity: the app keeps its own accent; learning surfaces use the learning accent and per-card faces.

## Development Workflow

- Every feature follows Spec Kit: constitution -> `/speckit-specify` -> `/speckit-clarify` (when needed) ->
  `/speckit-plan` -> `/speckit-tasks` -> `/speckit-analyze` -> `/speckit-implement`.
- The plan's Constitution Check MUST pass (or violations are justified in Complexity Tracking) before tasks.
- A feature is done when its tasks are checked, Pester tests pass, the quickstart scenarios pass in a browser, and
  the related Claude skills are updated.

## Governance

This constitution overrides other practices for Stranote. Amendments are made with `/speckit-constitution`, must state
the reason, bump the version (MAJOR: a principle removed or redefined; MINOR: a principle or section added;
PATCH: wording) and update dependent templates. Every plan and review checks compliance with Principles I-VII.

**Version**: 1.0.0 | **Ratified**: 2026-10-19 | **Last Amended**: 2026-10-19
