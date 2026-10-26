# Contract: task-type layout, versioned save places, file versions

Additive to `specs/001-career-packs-onboarding/contracts/pack-schema.md` (`taskTypes[]`, `settings.saveTargets`) and
to spec 004 `contracts/intake-fields.md`. Every field is optional; a pack or `overrides.json` written before this
feature stays valid and behaves as today.

## `taskTypes[]` (new optional fields)

| Field | Type | Default | Meaning |
|---|---|---|---|
| `folders` | string[] | - (use `settings.ticketFolders`) | sub-folders created in a new task of this type; each passes `Test-RelPath`; max 20 |
| `saveTargets` | save target[] | - | the type's own save places (same shape as `settings.saveTargets` + `versioned`); each `path` starts with `{ticket}` |
| `attachmentsPath` | string | - (use `settings.attachmentsPath`) | the type's attachments (requester) folder; starts with `{ticket}`; under the work root |
| `useBaseChecklist` | bool | `true` | `false` = `settings.baseChecklist` is not added to this type's tasks |
| `useCommonQuestions` | bool | `true` | `false` = `settings.commonQuestions` are not added to this type's tasks |
| `phases` | `{ name, percent?, column }[]` | - (use `settings.phases`) | the type's own phases; must include `Done`; `column` = a name in `settings.phases` (the board column); `Done` -> `Done`, `On Hold` -> `On Hold`; unique names; percent 0-100 or empty |

Phase rules: new tasks of the type start in its first phase; the update dialog / terminal offer the type's phases (plus
the task's current phase if it is no longer listed); the board places a card in `column` of its phase (unknown phase:
today's extra column) and shows the task's phase name when it differs from the column; `Get-SnMeta` sends per type
`phases` and `phaseColumn` / `phasePct` maps. `Done` and `On Hold` keep their special meaning everywhere.

Save places shown for a task of a type with `saveTargets`: the type's `saveTargets`, then the general
`settings.saveTargets` whose `path` does NOT start with `{ticket}`. Without `saveTargets`: all general ones (today).
Save-target indexes sent by the page refer to this resolved list (`Get-SnTaskTargets`), never to the raw setting.

Validation (pack loader and `Assert-SnSettings`), path-style messages, e.g.
`taskTypes[9].folders[1]: '..\x' is not a safe relative folder`; `taskTypes[9].saveTargets[0].path must start with {ticket}`.

## Save target (`settings.saveTargets[]` and `taskTypes[].saveTargets[]`)

| Field | Type | Default | Meaning |
|---|---|---|---|
| `name`, `path`, `prefix` | - | today | unchanged |
| `versioned` | bool | `false` | first file of a family is saved as `<name>_v1.<ext>`; the version question pre-selects "new version" when a family matches |

## File family and version (engine rule, one function `Get-SnFileFamily`)

- `stem` = file name without extension; if it ends with `_v<n>` (n = 1..999, case-insensitive), family = stem without
  that ending and version = n; else family = stem and version = 1.
- Families are per folder (place + sub-folder). Family match is case-insensitive.
- Next version = max version of the family in that folder + 1; the free-name loop still guards against a race (never
  overwrite).

## `Save-SnFile` (additive parameters)

| Parameter | Meaning |
|---|---|
| `-VersionOf <family>` | save as the next version of that family in the destination folder (extension from `-FileName`) |
| `-AsNew` | save as a new family; refused with a clear message if the name exists (the page then offers version/rename) |
| `-Note <text>` | "what changed", max 200 chars, stored on the record and logged |
| neither | today's behaviour (free name `_v2`, `_v3` ...) - kept for old callers and scripts |

`Get-SnFileFamilies -Id <task> [-Target <n> | -Attachment] [-SubFolder <s>]` -> `[{ family, latest, version, at, ext }]`,
newest first.

## Server

- `GET /api/families?id=&target=&attachment=&sub=` -> families of that folder (read-only).
- `POST /api/savefile` accepts `versionOf`, `asNew`, `note` (strings/bool); same `X-EBS: 1` write header.
- `GET /api/meta` sends each type's layout fields (folders, saveTargets, attachmentsPath, the two switches).

## Task record (additive)

`files[]` keeps `{ at, path, target, question?, original? }`; new optional `family`, `version` (int), `follows`
(relative path of the previous version), `note`.

## Example (EBS technical, Data request)

```json
{ "name": "Data request",
  "useBaseChecklist": false, "useCommonQuestions": false,
  "phases": [
    { "name": "Requested", "percent": 10, "column": "Requirements" },
    { "name": "Query written", "percent": 40, "column": "Development" },
    { "name": "Data sent", "percent": 70, "column": "UAT" },
    { "name": "Confirmed", "percent": 90, "column": "UAT" },
    { "name": "On Hold", "column": "On Hold" },
    { "name": "Done", "percent": 100, "column": "Done" }
  ],
  "folders": ["01_From_Requester", "02_Scripts", "03_Data"],
  "attachmentsPath": "{ticket}\\01_From_Requester",
  "saveTargets": [
    { "name": "Query script", "path": "{ticket}\\02_Scripts", "prefix": false, "versioned": true },
    { "name": "Data sheet", "path": "{ticket}\\03_Data", "prefix": false, "versioned": true },
    { "name": "From requester (their script, screenshots)", "path": "{ticket}\\01_From_Requester", "prefix": false }
  ],
  "questions": [
    { "k": "need", "q": "What data is needed and why (the business question)", "kind": "long", "required": true },
    { "k": "instance", "q": "Instance to query (PROD / UAT / DEV)", "d": "PROD" },
    { "k": "scope", "q": "Operating unit / ledger / organization", "d": "" },
    { "k": "filters", "q": "Filters and parameters (period, dates, statuses)", "kind": "long",
      "askIfBlank": "Which filters / date range should the data cover?" },
    { "k": "columns", "q": "Columns needed (or attach their sample sheet)", "kind": "long",
      "askIfBlank": "Which columns does the requester need?" },
    { "k": "output", "q": "Output wanted", "kind": "choice", "d": "Excel sheet",
      "options": ["Excel sheet", "CSV file", "In the email body / screenshot", "SQL only (they run it)"] },
    { "k": "repeat", "q": "One time or recurring?", "kind": "choice", "d": "One time",
      "options": ["One time", "Recurring (may become a report)"] },
    { "k": "reqFiles", "q": "Their script / screenshots / sample sheet", "kind": "files" }
  ],
  "openQuestions": ["Is querying PROD allowed, or should it run on a clone?",
                    "Does the data contain personal or sensitive fields that must be masked or left out?"],
  "variants": [ { "when": { "k": "repeat", "is": "Recurring (may become a report)" },
                  "openQuestions": ["Is querying PROD allowed, or should it run on a clone?",
                                    "Does the data contain personal or sensitive fields that must be masked or left out?",
                                    "Will this be needed again: should it become a report (new Report task)?"] } ],
  "checklist": ["Need, filters and columns confirmed with the requester",
                "Query written and run on the agreed instance",
                "Row count and totals checked against the application screens or a known figure",
                "Data sheet saved in 03_Data and sent to the requester",
                "Requester confirmed the data is right",
                "Reusable query saved as a snippet (if it will be needed again)"],
  "objects": [] }
```
