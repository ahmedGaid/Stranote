# Writing a career pack

A **career pack** is one JSON file that teaches Stranote about a job: its areas of work, task types, checklists,
the words the dashboard shows, the onboarding questions, and the patterns that turn work files into knowledge
cards. A new career is a new pack, not new code (constitution principle 1).

This guide walks through writing and checking a pack. The full field reference is
[`specs/001-career-packs-onboarding/contracts/pack-schema.md`](../specs/001-career-packs-onboarding/contracts/pack-schema.md).
The shipped packs in [`packs/`](../packs/) are working examples. `nurse.json` and `general.json` are the easiest
to read.

## 1. Where packs live

| Location | Who it is for |
|---|---|
| `packs\<id>.json` in the repo (copied to `<tool>\packs\` on install) | packs shipped with Stranote |
| `<learn dir>\packs\<id>.json` (e.g. `D:\Work\04_Knowledge\Stranote\packs`) | one person's own packs |
| `$env:STRANOTE_PACKS_DIR` | extra folder (tests, experiments) |

The search order is custom, then `STRANOTE_PACKS_DIR`, then shipped. When two packs share an id, the custom one wins,
so you can copy a shipped pack into your learn dir and change it without touching the install.

Rules for the file:

- The file name is the pack id: `nurse.json` has `"id": "nurse"`. The id is kebab-case (`^[a-z0-9]+(-[a-z0-9]+)*$`).
- Save it as UTF-8 (Arabic `labelAr` text must survive).
- Never put real people, customers, patients or secrets in a pack. Placeholders and samples are fictional.

## 2. How a pack becomes settings

```
src\settings.default.json   (engine defaults, career-neutral)
   <- active pack           (areas -> modules, taskTypes -> types, categories -> knowledge, pack.settings)
   <- overrides.json        (the person's own changes, kept across pack updates)
```

The active pack is the `packId` of the first role in `profile.json`. Change the pack and the person's overrides and
progress stay. Card ids depend only on the task and topic, so a pack update never loses progress.

## 3. The top-level fields

Unknown top-level fields are errors (this catches typos). Use an `x-` prefix (`"x-notes": ...`) for experiments.

### Identity

```json
"schemaVersion": 1,
"id": "nurse",
"name": "Nurse",
"field": "Healthcare",
"version": "1.0.0",
"description": "Nursing work in any unit. Never store real patient data.",
"levels": ["Student", "Junior", "Mid", "Senior", "Lead"]
```

`name`, `field` and `version` are required. Bump `version` when you change a shipped pack.

### `categories` and `categoryRules`

Categories group knowledge cards (the Learn page filters and colours use them). You need at least one.

```json
"categories": [
  { "id": "Clinical",   "label": "Clinical",   "labelAr": "إكلينيكي", "color": "#2563eb" },
  { "id": "Medication", "label": "Medication", "labelAr": "أدوية",    "color": "#2f8f5b" }
],
"categoryRules": { "byKind": { "answer": "Communication", "term": "Clinical" }, "default": "Clinical" }
```

A card's category is `byKind[card kind]`, else its area's category, else `default`. Every value must be a category id.

### `areas`

Areas are the parts of the job. Areas with `"taskModule": true` become the task **Module** list, in pack order.
`concepts` are the topics a person in that area should know.

```json
{ "id": "MEDS", "name": "Medication administration", "category": "Medication", "taskModule": true,
  "concepts": [
    { "id": "med-rights", "title": "The rights of medication administration" },
    { "id": "med-calc",   "title": "Dose calculations: mg/kg, infusion rates in mL/h" }
  ] }
```

Area ids must be unique, and concept ids must be unique inside their area. Add a catch-all `{ "id": "Other", "name": "Other", "taskModule": true, "concepts": [] }`.

### `taskTypes`

These are the kinds of work a person logs. Each type brings its intake questions (`k` = key, `q` = question,
`d` = default), the open questions to keep in mind, and the checklist.

```json
{ "name": "Patient case",
  "questions": [ { "k": "case", "q": "Case summary (no names: age range, condition, unit)", "d": "" } ],
  "openQuestions": ["What would make me escalate this patient?"],
  "checklist": ["Assessment done and charted", "Handover written"],
  "objects": [] }
```

Names must be unique, and checklist items cannot be empty. Add an `Other` type.

**Branching intake (optional).** A question can be a list (`"kind": "choice"` with `options`), a multi-line answer
(`"kind": "long"`), or a drop area for files (`"kind": "files"`, with an optional `sub` folder inside the attachments
folder). `"required": true` blocks creation while it is blank. `"when": { "k": "<choice key>", "is": "<option>" }` (or
`"in": [...]`) shows a question only for that answer; the choice must come earlier in the list, and conditions can be at
most 2 levels deep. `"askIfBlank": "..."` turns a blank answer into an open question. `variants` replace the type's
`openQuestions`, `checklist` and `objects` when their `when` matches. Questions without these fields work as before.

```json
{ "name": "Patient case",
  "questions": [
    { "k": "mode", "q": "New case or follow-up?", "kind": "choice", "options": ["New case", "Follow-up"], "required": true },
    { "k": "change", "q": "What changed since the last shift", "kind": "long", "when": { "k": "mode", "is": "Follow-up" },
      "askIfBlank": "What changed since the last shift?" },
    { "k": "photos", "q": "Wound photos (no faces)", "kind": "files", "sub": "Photos", "when": { "k": "mode", "is": "Follow-up" } }
  ],
  "variants": [ { "when": { "k": "mode", "is": "Follow-up" }, "checklist": ["Compared with the last assessment"] } ],
  "openQuestions": ["What would make me escalate this patient?"],
  "checklist": ["Assessment done and charted", "Handover written"],
  "objects": [] }
```
Full contract: `specs/004-task-attachments-report-intake/contracts/intake-fields.md`.

**Its own layout (optional).** A type can bring its own task sub-folders (`folders`, instead of
`settings.ticketFolders`), its own save places (`saveTargets`, paths start with `{ticket}`; `"versioned": true` saves the
first file as `name_v1` so every version shows in its name), its own attachments folder (`attachmentsPath`), and can
leave out the general lists (`"useBaseChecklist": false`, `"useCommonQuestions": false`). It can also have its own
`phases`: each `{ "name", "percent", "column" }`, where `column` is one of the general phases (the board column it
shows in); `Done` is required and keeps the `Done` column, `On Hold` keeps `On Hold`. Anything left out uses the
general setting; existing tasks never change.

```json
{ "name": "Shift handover",
  "useBaseChecklist": false,
  "folders": ["01_Notes", "02_Photos"],
  "attachmentsPath": "{ticket}\\02_Photos",
  "saveTargets": [ { "name": "Handover sheet", "path": "{ticket}\\01_Notes", "prefix": false, "versioned": true } ],
  "phases": [ { "name": "Drafted", "percent": 30, "column": "In progress" },
              { "name": "Handed over", "percent": 90, "column": "Review" },
              { "name": "Done", "percent": 100, "column": "Done" } ],
  "checklist": ["Handover read back"], "openQuestions": [], "objects": [] }
```
Full contract: `specs/005-task-type-layouts-versions/contracts/type-layout.md`.

### `settings`

Any engine setting the pack wants to set: `phases`, `commonQuestions`, `baseChecklist`, `ticketFolders`,
`notesSections`, `saveTargets`, `attachmentsPath` (where attachments go inside the task folder, starts with
`{ticket}`; default `{ticket}\Attachments`), `workFolders`, `abbreviations`, `stopWords`, `prefix`... Look up names and defaults in
`src\settings.default.json`. Do not set `modules`, `types` or `knowledge` here, because they are built from `areas`,
`taskTypes` and `categories`.

```json
"settings": {
  "phases": [ { "name": "Not started", "percent": 0 }, { "name": "In progress", "percent": 50 }, { "name": "Done", "percent": 100 } ],
  "ticketFolders": ["01_Notes", "02_Files", "03_Protocols"],
  "saveTargets": [ { "name": "Protocol or guideline", "path": "{ticket}\\03_Protocols", "prefix": false } ],
  "attachmentsPath": "{ticket}\\01_Notes\\Attachments",
  "abbreviations": { "MEDICATION": "MED", "HANDOVER": "HO" }
}
```

### `ui`: the words the dashboard shows

The dashboard template has no career words in it, so all career wording comes from the pack. Every key is optional and
falls back to a neutral default ("Area", "Workspace"...). A test fails if EBS words come back into the template, so put
career words here and never in `dashboard_template.html`.

```json
"ui": {
  "workspace": "Nursing workspace",
  "area": "Unit area", "areas": "Unit areas",
  "cvTitle": "Registered Nurse",
  "privateNamesWarning": "contains a patient identifier",
  "sample": { "id": "CASE-0142", "module": "MEDS", "type": "Medication administration",
              "title": "Heparin_infusion_titration", "code": "HEP_INF" },
  "placeholders": { "taskTitle": "e.g. Heparin infusion titration" },
  "privateNames": "\\b(MRN|bed|room|DOB)\\b",
  "skills": { "areaSkill": "{name}", "bullet": "{verb} {title} ({name})" },
  "cvTips": [ { "title": "Show outcomes", "text": "Say what changed for the patient or the team." } ]
}
```

`privateNames` and the `skills.*` patterns are **JavaScript** regexes, because they run in the browser.
`privateNamesWarning` is the pack-specific CV warning shown when the prefix or `privateNames` pattern matches; it
falls back to a neutral message when omitted. Extractor patterns are .NET regexes. The schema contract lists every `ui` key.

### `onboardingQuestions`

The extra questions the onboarding wizard asks for this career. `type` is `select` (with `options`) or `text`.
`writesTo` decides where the answer goes:

| `writesTo` | Saved to |
|---|---|
| `settings.<path>` | the person's settings (as an override) |
| `profile.<path>` | `profile.json` at that path |
| `pack.<name>` | `profile.json` -> `packAnswers.<name>` |

```json
{ "id": "unit", "label": "Which unit do you work in?", "type": "select",
  "options": ["ICU / critical care", "Emergency", "Medical ward"], "default": "Medical ward", "writesTo": "pack.unit" }
```

### `extractors`

These turn work files into knowledge cards. See [section 4](#4-extractors).

### `skillMap`, `vocabulary`, `starterLessons`

- `skillMap`: `[{ "skill": "Safe medication administration", "area": "MEDS", "group": "Medication" }]`. The validator
  accepts it, but the CV page builds skills from `ui.skills` today. Fill it anyway, because the pack builder (T042) will use it.
- `starterLessons`: keep it `[]` for now. It is reserved for the onboarding first-week plan. No shipped pack has lessons yet.
- Abbreviations and stop words go in `settings.abbreviations` and `settings.stopWords`.

## 4. Extractors

An extractor reads a task's files line by line with a .NET regex and makes cards. `task.json` is never read. There
are three kinds:

| Kind | Finds | Required groups | Example |
|---|---|---|---|
| `api` | calls like `PACKAGE.member` | `(?<pkg>...)` and `(?<member>...)` | EBS `FND_REQUEST.SUBMIT_REQUEST` |
| `table` | names of tables/objects, with how they are used (INSERT/UPDATE/...) | `(?<key>...)` | EBS `AP_INVOICES_ALL` |
| `term` | any words or terms in plain notes | `(?<key>...)` | drug names, tools, scores |

`api` and `table` are for code-heavy careers. Copy them from `packs\oracle-ebs-technical.json`. Most careers only
need `term`.

### A worked `term` extractor

Goal: a nurse writes shift notes in `.txt`/`.md` files, and every drug they gave should become a card.

```json
{ "id": "nurse-drugs", "kind": "term",
  "files": [".txt", ".md"],
  "pattern": "(?i)\\b(?<key>heparin|insulin|noradrenaline|propofol|paracetamol)\\b",
  "group": "Medication",
  "minCount": 1,
  "maxCards": 6,
  "cardTemplate": { "topic": "Drug: {key}", "fact": "Given in {taskId}: {context}" } }
```

Take a task `T-0007` with a file `shift.txt`:

```
- Heparin 5000 units given at 08:00
heparin rechecked with the APTT
Insulin before lunch
```

The engine counts each key case-insensitively per task (`heparin` = 2, `insulin` = 1), drops keys seen fewer than
`minCount` times, keeps the most used `maxCards`, and makes one card per key:

| Card field | Value |
|---|---|
| topic | `Drug: Heparin` (`{key}` = the first spelling seen) |
| fact | `Given in T-0007: Heparin 5000 units given at 08:00  (shift.txt)` (`{context}` = the first line it was seen on, without list/heading marks, cut to about 170 characters; the file name is added) |
| category, tag | `Medication` (from `group`, which must be a category id) |
| question | one flash question, so the card joins the daily review |

Other `term` fields: `excludePattern` (keys to ignore), `commentPattern` (lines to skip), and `label` (the topic
prefix when there is no `cardTemplate`).

Tips:

- Put `(?i)` at the start for case-insensitive matching. Leave it off when lower-case words would cause false hits.
  The nurse `scores` extractor is case-sensitive so "news" and "must" do not match NEWS and MUST.
- Wrap the list in `\b...\b` so `GTN` does not match inside a longer word.
- In JSON, every regex backslash is written twice: `\\b`, `\\s`.
- Keep `maxCards` small (4-8). A few strong cards beat 30 weak ones.

### The speed rule

`Test-SnPack` runs every extractor regex (`pattern`, `excludePattern`, `commentPattern`, `packagePattern`,
`snippetEnd`) over a 50 KB sample that starts with a backtracking trap. A pattern that takes **250 ms or more**, or that
hits the 200 ms match timeout, is rejected as `too slow`. To stay fast:

- Use plain alternation of literal words: `(?<key>a|b|c)`.
- Avoid nested quantifiers like `(\w+\s*)+` and long `.*` runs between groups.
- Anchor with `\b` or `^` so the engine can skip quickly.

## 5. Validate the pack

```powershell
Import-Module D:\Projects\Stranote\src\Stranote.psm1 -Force -DisableNameChecking
Test-SnPack -Path D:\Projects\Stranote\packs\nurse.json
```

The result is `{ ok, errors[] }`. Every error names its JSON path, for example:

```
areas[3].category: 'Clinicals' is not a category id
extractors[0].pattern: needs a (?<key>...) group
extractors[1].pattern: too slow (over 250 ms on 50 KB)
x_notes: unknown field          (use "x-notes" for an experiment field)
```

The checks are: schemaVersion 1; the id is kebab-case and matches the file name; `name`, `field` and `version` are set;
categories, areas and task types are present and unique; every category reference (`areas[].category`,
`categoryRules`, `extractors[].group`) exists; extractor kinds are `api`, `table` or `term`, and their regexes compile,
have the required groups and pass the speed rule; `ui` is an object; `onboardingQuestions[].writesTo` starts with
`settings.`, `profile.` or `pack.`.

An invalid pack never loads. `Get-SnPack` throws with the same error list, and the profile cannot be switched to it.

## 6. Add samples and run the tests

Every shipped pack needs **5 fictional work files** in `samples\<pack-id>\`, for example the notes, scripts or reports a
person in that career really writes. `tests\StranoteSamples.Tests.ps1` picks up every pack in `packs\` automatically. It
makes one task per sample, syncs knowledge, and checks that:

- the pack has exactly 5 sample files,
- the samples produce **at least 10 knowledge cards**,
- every card lands in one of the pack's categories.

```
samples\nurse\
  01_shift_handover.md
  02_icu_sedation.txt
  03_falls_pressure.md
  04_insulin_sliding.txt
  05_cardiac_arrest_debrief.md
```

Write samples the way the person would. Use the file types your extractors read (`files`). Mention a mix of terms
so every extractor fires at least once. Mark each file as fictional, and use no real names, ids or patient details.

```powershell
powershell -NoProfile -Command "Invoke-Pester D:\Projects\Stranote\tests\StranoteSamples.Tests.ps1"
# whole suite (2-3 min):
powershell -NoProfile -Command "Invoke-Pester D:\Projects\Stranote\tests"
```

If a pack makes fewer than 10 cards, widen the term lists or lower `minCount`, rather than padding the samples
with lists of words.

## 7. Try it in the dashboard

Run a dev server on a temporary config, so real data is never touched, and pick the pack in onboarding or in
Settings:

```powershell
$env:STRANOTE_NO_SCHEDULE = '1'
powershell -ExecutionPolicy Bypass -File D:\Projects\Stranote\src\StranoteServer.ps1 -Port 8766 -Config <temp config.json>
```

Check the sidebar workspace line, the area noun, the task form placeholders, the Settings previews (`ui.sample`), the
CV page and the Learn page (cards from a sample task). Check light and dark mode.

## Checklist

- [ ] File name = `id`, kebab-case, UTF-8
- [ ] Categories, areas (with `Other`), task types (with `Other`) and checklists filled in
- [ ] `ui` block written: no career words left in the template
- [ ] Onboarding questions with valid `writesTo`
- [ ] At least one extractor, all patterns fast and with the right named groups
- [ ] `Test-SnPack -Path ...` returns `ok = True`
- [ ] 5 fictional samples in `samples\<id>\` and the samples test passes (>= 10 cards)
- [ ] No real people, customers, patients or secrets anywhere

## A pack for one person's career (pack requests)

When someone picks **My career is not listed** in onboarding, Stranote saves a request in
`<learn dir>\pack-requests\<slug>.json` and keeps them on the General pack. Then:

1. The Claude skill `stranote-pack-builder` ("build my Stranote pack") drafts `<learn dir>\packs\<slug>.json` from the
   request and a few questions. Anything it adds that the person did not say is listed in `"x-unconfirmed"`.
2. `Submit-SnPackDraft -Slug <slug>` validates the draft and marks the request `drafted`.
3. The person reviews it in **Settings > Roles** and clicks **Accept and switch role** (`Approve-SnPackDraft`) or
   **Reject** (`Deny-SnPackDraft`; the draft moves to `pack-requests\rejected\`). Tasks, cards and progress are kept.
