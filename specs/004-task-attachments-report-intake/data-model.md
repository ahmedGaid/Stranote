# Data model: task attachments and report intake

All changes are additive (Principle IV). No migration; old tasks and packs read as before.

| Where | Field | Change |
|---|---|---|
| `packs/<id>.json` `taskTypes[].questions[]` | `kind`, `options`, `required`, `when`, `askIfBlank`, `sub` | new, optional ([contract](contracts/intake-fields.md)) |
| `packs/<id>.json` `taskTypes[].variants[]` | `when`, `openQuestions`, `checklist`, `objects` | new, optional |
| `src/settings.default.json` / pack `settings` | `attachmentsPath` | new, default `{ticket}\\Attachments`; EBS packs `{ticket}\\01_Requirements\\Attachments` |
| `overrides.json` | `types`, `attachmentsPath` | may hold them after a Settings save; editor keeps every field |
| `task.json` `details[]` | `k` | new, optional; hidden questions are not stored |
| `task.json` `files[]` | `question`, `original` | new, optional; `target` = `Attachments` for attachments |
| `task.json` `questions[]` | - | `askIfBlank` texts are added like any open question |
| `_NOTES.md` | `## Details`, `## Progress log` | fix answers listed as today; each attachment logged `FILE` as today |
| Work folder | `01_Tickets\<task>\<attachmentsPath>\[Problem\|Expected\]\<file>` | files written; never in the repo |

Folder example (EBS technical, Report fix `T-0042`):

```text
D:\Work\01_Tickets\T-0042_AP_Report_Supplier_aging\
  _NOTES.md  task.json
  01_Requirements\Attachments\
    email_from_finance.msg
    Problem\screenshot_20261024_1655.png  output_wrong_totals.xlsx
    Expected\expected_layout.xlsx
  02_Design\ 03_Dev\ 04_Test\ 05_Deploy\
```
