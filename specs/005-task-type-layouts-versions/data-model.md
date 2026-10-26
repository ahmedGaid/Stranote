# Data model: task-type layouts, Data request type and file versions

All changes are additive (Principle IV). No migration; old tasks, packs and files read as before.

| Where | Field | Change |
|---|---|---|
| `packs/<id>.json` `taskTypes[]` | `folders`, `saveTargets`, `attachmentsPath`, `useBaseChecklist`, `useCommonQuestions` | new, optional ([contract](contracts/type-layout.md)) |
| `settings.saveTargets[]`, `taskTypes[].saveTargets[]` | `versioned` | new, optional, default false |
| `overrides.json` `types` | same fields | kept by the Settings editor; empty folders list = field removed (fallback) |
| `task.json` `files[]` | `family`, `version`, `follows`, `note` | new, optional |
| `task.json` `checklist[]`, `questions[]` | - | built without the general lists when the type turns them off |
| `_NOTES.md` `## Progress log` | `FILE` line | adds "version n of <family>: <note>" when present |
| Work folder | `01_Tickets\<task>\<type folders>` | created at task creation; old tasks untouched |

Folder example (EBS technical, Data request `T-0050`, after two rounds with the requester):

```text
D:\Work\01_Tickets\T-0050_AP_DataRequest_Invoices_on_hold\
  _NOTES.md  task.json
  01_From_Requester\
    their_query.sql  screenshot_20261026_1015.png
  02_Scripts\
    AP_holds_query_v1.sql  AP_holds_query_v2.sql      (v2: added supplier site)
  03_Data\
    AP_holds_v1.xlsx  AP_holds_v2.xlsx                (v2: added supplier site)
```

`files[]` entry for the second sheet:

```json
{ "at": "2026-10-26 14:02", "path": "01_Tickets\\T-0050_...\\03_Data\\AP_holds_v2.xlsx", "target": "Data sheet",
  "original": "Book1.xlsx", "family": "AP_holds", "version": 2,
  "follows": "01_Tickets\\T-0050_...\\03_Data\\AP_holds_v1.xlsx", "note": "added supplier site" }
```
