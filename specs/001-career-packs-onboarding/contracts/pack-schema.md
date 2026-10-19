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
3. `taskTypes[].name` unique; `checklist` items non-empty strings.
4. `extractors[].pattern` compiles as .NET regex, has a `key` group, and matches a 50 KB sample in < 200 ms.
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
`checklist[]`, `objects[]`).

**settings**: any engine setting the pack provides (phases, folders, saveTargets, abbreviations, prefix...).
`modules`, `types` and `knowledge` are derived from `areas`, `taskTypes`, `categories` and `categoryRules`.

**Extractors** (code kinds; `term` arrives with US3):

| Field | api | table | Meaning |
|---|---|---|---|
| `pattern` | `(?<pkg>)` + `(?<member>)` | `(?<key>)` | .NET regex run per line |
| `files` | yes | yes | file extensions to read |
| `commentPattern` | yes | yes | lines matching it are skipped |
| `skipMembers` | yes | - | members to ignore (e.g. `NEXTVAL`) |
| `skipOwnPrefix` | yes | yes | ignore the person's own objects (`<prefix>_...`) |
| `excludePattern` | - | yes | keys to ignore (e.g. `_PKG$`, `_S$`) |
| `packagePattern` | - | yes | in suggestions, keys that look like packages count as APIs |
| `operations` | - | yes | ordered `{ INSERT: regex with {key}, ... }`; first match wins, else REFERENCE |
| `maxCards`, `groupThreshold` | 8, 3 | 6 | card limits; 3+ members of one package -> one package card |
| `snippetLines`, `snippetEnd` | 8, `;\s*$` | - | code snippet stored on the card |
| `label` | `API` | `Table` | card topic prefix (`API: FND_PROGRAM`) |
| `question` | template | - | `{members}`, `{ref}` placeholders for the fill-the-blank question |

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
| `privateNames` | JS regex: text the CV checker flags as internal object names (besides the prefix) |
| `skills.areaSkill` | skill name for an area; tokens `{module}`, `{MODULE}`, `{name}` (default `{name}`) |
| `skills.areaGroup`, `skills.typeGroup` | CV groups for area and task-type skills |
| `skills.groups` | CV group order |
| `skills.types` | `{ taskType: skill name }` |
| `skills.rules[]` | `{ key, name, group, types?, details?, checklist?, tag? }`: a task gets the skill when all given conditions hold (type in `types`, intake answers match `details`, a done checklist item matches `checklist`); a card/question tag matching `tag` maps to it. Regexes are JavaScript, case-insensitive |
| `skills.apis` | `{ group, patterns[] (JS regex, group 1 = name), tag }`: API names found in intake answers or tags |
| `skills.verbs`, `skills.bullet` | CV draft: `{ taskType: verb }` and a template with `{verb} {title} {module} {MODULE} {name} {api}` |
| `cvTips[]` | `{ title, text }` CV writing hints |

Card ids stay `A-<md5(taskId|topic)>` and question ids `QB-<md5(taskId|key)>`, so progress survives the upgrade.
