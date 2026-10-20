---
name: stranote-status
description: Read-only Stranote project status report, for any agent (Claude Code, Codex, Copilot). Use when the user types /stranote_status, $stranote-status or asks "Stranote status" / "where are we on Stranote", optionally with a focus such as "blockers".
---

# Stranote status (read-only)

Read ONLY the `## CURRENT STATE` block in `D:\Projects\Stranote\STATE.md`. Do NOT explore the codebase and do not
change any file. If the user passed an argument (e.g. "blockers"), focus the report on it. Output:

---
## Stranote - Status
**Phase:** ...
**Working now:** [each claimed row: agent - id - since - branch, or "nobody"]
**Waiting for review:** [rows in review / reviewing]
**Ready to merge** (owner types `/stranote_resume merge`): [approved rows]
**Next open tasks:** [first 3 open rows: id - title - fit]
**Blocked on owner** (n): [ids + one line each]
**Recent:** [latest 3 log lines]
---

If no CURRENT STATE block exists, say so and suggest `/stranote_resume update`.
