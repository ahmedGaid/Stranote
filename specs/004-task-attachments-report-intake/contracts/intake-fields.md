# Contract: intake question fields, task-type variants, attachments place

Additive to `specs/001-career-packs-onboarding/contracts/pack-schema.md` (`taskTypes[]` and `settings`). Every field
below is optional; a pack or an `overrides.json` written before this feature stays valid and behaves as today.

## `taskTypes[].questions[]`

| Field | Type | Default | Meaning |
|---|---|---|---|
| `k` | string | required (today) | answer key, unique in the type |
| `q` | string | required (today) | label |
| `d` | string | `""` | default value (for `choice`: one of `options`) |
| `kind` | `text` \| `long` \| `choice` \| `files` | `text` | input shown; `long` = multi-line; `files` = drop area |
| `options` | string[] | - | required when `kind` = `choice`; 2-30 items, unique, non-empty |
| `required` | bool | false | the task cannot be created while this visible question is blank (not for `files`) |
| `when` | `{ "k": "<key>", "is": "<value>" }` or `{ "k": "<key>", "in": ["a","b"] }` | - | shown only when that answer matches (case-insensitive); `k` must be an earlier `choice` question of the same type |
| `askIfBlank` | string | - | if the question is visible and left blank, this text is added as an open question (not for `files`) |
| `sub` | string | `""` | `files` only: relative sub-folder of the attachments place (`Problem`, `Expected`) |

Validation (pack loader and settings save): unknown `kind`; `choice` without `options`; `d` not in `options`; `when.k`
not an earlier `choice` question; `when.is` / `when.in` not in that question's options; `sub` not a valid relative
folder (`Test-RelPath`); a cycle or chain deeper than 2 levels -> error with the path, e.g.
`taskTypes[0].questions[3].when.k: 'mode' is not an earlier choice question`.

## `taskTypes[].variants[]`

```json
{ "when": { "k": "mode", "is": "Fix an existing report" },
  "openQuestions": ["..."], "checklist": ["..."], "objects": ["..."] }
```

The first variant whose `when` matches the answers replaces the type's `openQuestions`, `checklist` and `objects` (each
only if the variant defines it). `when.k` must be a `choice` question of the type. No match -> the type's own lists.

## `settings.attachmentsPath`

Pattern relative to the task folder, starts with `{ticket}`; tokens as save targets (`{id}`, `{module}`, `{type}`).
Engine default `{ticket}\Attachments`, in code (not in `src/settings.default.json`, see data-model.md). Must resolve under the work root (`Assert-UnderRoot`).

## Task record (additive)

- `details[]` keeps `{ q, a }`; new optional `k` (answer key), so the page can find `mode` without parsing labels.
- `files[]` keeps `{ at, path, target }`; attachments use `target` = `"Attachments"` and new optional
  `question` (the `k` of the file question, empty = general) and `original` (the name before the safe rename).

## Example (EBS technical, Report)

```json
{ "k": "mode", "q": "New report or fix an existing one?", "kind": "choice",
  "options": ["New report", "Fix an existing report"], "required": true },
{ "k": "tech", "q": "Technology (BIP / Oracle Reports / SQL text output)", "d": "BIP",
  "when": { "k": "mode", "is": "New report" } },
{ "k": "rtype", "q": "Report type in EBS", "kind": "choice", "when": { "k": "mode", "is": "Fix an existing report" },
  "options": ["Oracle Reports (RDF)", "BI Publisher - RDF data model", "BI Publisher - data template (XML)",
              "BI Publisher - PL/SQL or SQL*Plus XML", "SQL*Plus / PL/SQL text output", "FSG", "Discoverer",
              "Web ADI / Excel", "OAF page / export", "Other"] },
{ "k": "params", "q": "Parameters that raise the problem (exact values)", "kind": "long",
  "when": { "k": "mode", "is": "Fix an existing report" }, "askIfBlank": "Which parameter values raise the problem?" },
{ "k": "problemFiles", "q": "Screenshots / output that show the problem", "kind": "files", "sub": "Problem",
  "when": { "k": "mode", "is": "Fix an existing report" } }
```
