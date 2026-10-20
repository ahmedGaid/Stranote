---
name: stranote-status
description: Read-only Stranote project status report, for any agent (Claude Code, Codex). Use when the user types /stranote_status, $stranote-status or asks "Stranote status" / "where are we on Stranote", optionally with a focus such as "blockers".
---

# Stranote status (read-only)

Read ONLY the `## CURRENT STATE` block in `D:\Projects\Stranote\STATE.md`. Do NOT explore the codebase and do not
change any file. If the user passed an argument (e.g. "blockers"), focus the report on it. Output:

---
## Stranote - Status
**Phase:** ...
**Working now:** ... (who holds the current task, or free)
**Last agent:** ...
**Progress**
- ✅ done
- 🔨 in progress / next
- ⬜ not started
**Blockers** (n)
**Next action:** ...
**Agent fit:** ...
---

If no CURRENT STATE block exists, say so and suggest `/stranote_resume update`.
