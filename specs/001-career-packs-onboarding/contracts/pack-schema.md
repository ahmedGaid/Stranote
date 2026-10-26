# Contract: Career pack JSON (schemaVersion 1)

Minimal valid pack:

```json
{
  "schemaVersion": 1,
  "id": "nurse",
  "name": "Nurse",
  "field": "Healthcare",
  "version": "1.0.0",
  "levels": ["Student", "Junior", "Mid", "Senior", "Lead"],
  "categories": [
    { "id": "Clinical", "label": "Clinical", "labelAr": "إكلينيكي", "color": "#2563eb" },
    { "id": "Medication", "label": "Medication", "labelAr": "أدوية", "color": "#2f8f5b" }
  ],
  "areas": [
    { "id": "VENT", "name": "Mechanical ventilation", "category": "Clinical",
      "concepts": [ { "id": "vent-modes", "title": "Ventilator modes: AC, SIMV, PSV" } ] }
  ],
  "taskTypes": [
    { "name": "Patient case", "questions": ["Diagnosis?", "Key orders?"], "openQuestions": [],
      "checklist": ["Vitals charted", "Handover note written"], "objects": [] }
  ],
  "folders": { "ticket": ["01_Notes", "02_Files"], "work": ["00_Inbox", "01_Cases", "04_Knowledge"], "notesSections": ["Summary", "Decisions"] },
  "saveTargets": [],
  "extractors": [
    { "id": "drugs", "kind": "term", "pattern": "(?i)\\b(?<key>heparin|noradrenaline|propofol)\\b",
      "group": "Medication", "minCount": 1, "maxCards": 6,
      "cardTemplate": { "topic": "Drug: {key}", "fact": "Used in {taskId}: {context}" } }
  ],
  "starterLessons": [],
  "skillMap": [ { "skill": "Ventilator management", "area": "VENT", "group": "Clinical" } ],
  "vocabulary": { "abbreviations": { "PSV": "Pressure support ventilation" }, "stopWords": [] },
  "onboardingQuestions": [
    { "id": "unit", "label": "Which unit do you work in?", "type": "select", "options": ["ICU", "ER", "Ward"], "writesTo": "pack.unit" }
  ],
  "settings": {}
}
```

## Validation rules (`Test-SnPack` -> `{ ok, errors[] }`)
1. `schemaVersion` = 1; `id` matches `^[a-z0-9]+(-[a-z0-9]+)*$` and the file name.
2. `areas[].id` unique; every `areas[].category` exists in `categories[].id`.
3. `taskTypes[].name` unique; `checklist` items non-empty strings; intake fields and `variants` as in spec 004's
   `contracts/intake-fields.md`; layout fields as in spec 005's `contracts/type-layout.md`.
4. `extractors[].pattern` compiles as .NET regex, has a `key` group (`pkg` + `member` for `api`), and runs over a 50 KB sample in < 250 ms (200 ms match timeout). Guide: `docs/pack-authoring.md`.
5. `extractors[].kind` in `api | table | term | decision | answer`.
6. `starterLessons[]` pass `Set-SnLesson` validation (check questions mcq/tf only).
7. `onboardingQuestions[].writesTo` starts with `settings.`, `profile.` or `pack.`.
8. Unknown top-level fields are errors (catch typos); `x-` prefixed fields are allowed for experiments.

Errors name the JSON path, e.g. `areas[3].category: "Clinicals" is not a category id`.

## Fields as implemented (v1, from T015-T017)

**Areas**: `{ id, name, category?, taskModule?, concepts[] }`. Areas with `taskModule: true` become the task
"Module" list (in pack order). `category` is optional; areas without one use `categoryRules.default`.

**categoryRules**: `{ byKind: { answer: "Business", decision: "Business", api: "Technical", table: "Technical" },
default: "Technical" }`. A card's category = `byKind[card.kind]`, else the category of its area, else `default`.

**taskTypes**: same shape as the old `settings.types` (`name`, `questions[{k,q,d}]`, `openQuestions[]`,
`checklist[]`, `objects[]`). Optional intake fields on questions (`kind`, `options`, `required`, `when`,
`askIfBlank`, `sub`) and `variants[]` per type (spec 004): see
`specs/004-task-attachments-report-intake/contracts/intake-fields.md`; validated by rule 3. Optional layout fields
per type (`folders`, `saveTargets` with `versioned`, `attachmentsPath`, `useBaseChecklist`, `useCommonQuestions`;
spec 005): see `specs/005-task-type-layouts-versions/contracts/type-layout.md`; validated by rule 3.

**settings**: any engine setting the pack provides (phases, folders, saveTargets, abbreviations, prefix...).
`attachmentsPath` (spec 004): where attachments go inside the task folder, starts with `{ticket}`.
`saveTargets[].versioned` (spec 005, optional): the first file of a family in that place is saved as `<name>_v1`.
`modules`, `types` and `knowledge` are derived from `areas`, `taskTypes`, `categories` and `categoryRules`.

**Extractors** (code kinds `api`/`table`; word kind `term`, T037):

| Field | api | table | term | Meaning |
|---|---|---|---|---|
| `pattern` | `(?<pkg>)` + `(?<member>)` | `(?<key>)` | `(?<key>)` | .NET regex run per line |
| `files` | yes | yes | yes (default `.txt`, `.md`) | file extensions to read (`task.json` is never read) |
| `commentPattern` | yes | yes | yes | lines matching it are skipped |
| `skipMembers` | yes | - | - | members to ignore (e.g. `NEXTVAL`) |
| `skipOwnPrefix` | yes | yes | - | ignore the person's own objects (`<prefix>_...`) |
| `excludePattern` | - | yes | yes | keys to ignore (e.g. `_PKG$`, `_S$`) |
| `packagePattern` | - | yes | - | in suggestions, keys that look like packages count as APIs |
| `operations` | - | yes | - | ordered `{ INSERT: regex with {key}, ... }`; first match wins, else REFERENCE |
| `maxCards`, `groupThreshold` | 8, 3 | 6 | 6 | card limits per task; 3+ members of one package -> one package card |
| `minCount` | - | - | 1 | a term must appear this many times in the task's files to make a card |
| `snippetLines`, `snippetEnd` | 8, `;\s*$` | - | - | code snippet stored on the card |
| `label` | `API` | `Table` | (topic prefix if no `cardTemplate`) | card topic prefix (`API: FND_PROGRAM`) |
| `question` | template | - | - | `{members}`, `{ref}` placeholders for the fill-the-blank question |
| `cardTemplate` | - | - | `{ topic, fact }` | tokens `{key}` (first spelling seen), `{taskId}`, `{context}` (first line it was seen on) |
| `group` | - | - | category id | card category and tag (must be a `categories[].id`) |

Term keys are counted case-insensitively per task; the most used `maxCards` become cards (kind `term`, one flash question each).

**ui** (optional, T031): the wording the dashboard shows, so the template holds no career words. Everything is
optional; the page falls back to neutral defaults ("Area"/"Areas", "Workspace", generic placeholders and CV tips).
Sent to the page as `META.pack = { id, name, areaNames, ui }` (before migration: the EBS pack).

| Field | Meaning |
|---|---|
| `workspace` | sidebar line under the logo (`EBS workspace`) |
| `area`, `areas` | the noun for areas/task modules (`Module`, `Modules`): sidebar, filters, task form, settings |
| `screenshotsTitle` | heading of the screenshots section in the explanation window |
| `cvTitle` | CV export heading (default: pack `name`) |
| `sample` | `{ id, module, type, title, code }` used by the Settings previews (branch, folder, object names) |
| `placeholders` | `taskId, taskTitle, extraQuestions, cardTopic, cardFact, cardTags, scriptName, scriptPurpose, checklistItem, newArea, prefix, role, target, cvSkill` |
| `privateNames` | JS regex: private names or identifiers the CV checker flags (besides the prefix) |
| `privateNamesWarning` | CV warning text shown when the pack prefix or `privateNames` pattern matches (default: a neutral private name/identifier warning) |
| `skills.areaSkill` | skill name for an area; tokens `{module}`, `{MODULE}`, `{name}` (default `{name}`) |
| `skills.areaGroup`, `skills.typeGroup` | CV groups for area and task-type skills |
| `skills.groups` | CV group order |
| `skills.types` | `{ taskType: skill name }` |
| `skills.rules[]` | `{ key, name, group, types?, details?, checklist?, tag? }`: a task gets the skill when all given conditions hold (type in `types`, intake answers match `details`, a done checklist item matches `checklist`); a card/question tag matching `tag` maps to it. Regexes are JavaScript, case-insensitive |
| `skills.apis` | `{ group, patterns[] (JS regex, group 1 = name), tag }`: API names found in intake answers or tags |
| `skills.verbs`, `skills.bullet` | CV draft: `{ taskType: verb }` and a template with `{verb} {title} {module} {MODULE} {name} {api}` |
| `cvTips[]` | `{ title, text }` CV writing hints |

Card ids stay `A-<md5(taskId|topic)>` and question ids `QB-<md5(taskId|key)>`, so progress survives the upgrade.
