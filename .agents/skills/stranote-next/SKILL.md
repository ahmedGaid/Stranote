---
name: stranote-next
description: Tell any agent (Claude Code, Codex, Antigravity, Cline, Copilot) its next Stranote task in one read-only command, every day or session. Use when the user types /stranote_next, $stranote-next or asks "what's next on Stranote", "my next task", "what should I work on", "ايه التاسك الجاية", and as step 2 of /stranote_resume.
---

# Stranote - next task (read-only, every agent, every day)

One command gives every model the same answer, computed from `D:\Projects\Stranote\STATE.md` by the ladder in skill
`stranote-resume` (Mode A step 2). It changes nothing.

```
powershell -NoProfile -ExecutionPolicy Bypass -File D:\Projects\Stranote\.agents\skills\stranote-next\next.ps1 -Agent "<agent (model)>"
```
- `-Agent` = your agent and model as on the board, e.g. `"Codex (gpt-6-luna)"`, `"Claude Code (Opus 5.5)"`,
  `"Google Antigravity (Gemini)"`, `"Cline (MiniMax-M3.1-Flash)"`, `"GitHub Copilot (Auto)"`.
- `-Id <id>` if the user named a task. `-Small` if you run on a small model (Cline and Copilot always count as small).

Print what it returns as the brief (Next, Why, Fit, Touches, Working now, Blocked on owner, Ready to merge, Last done).
Do not explore the codebase and do not re-derive the answer by hand.

**Then:**
- Plain `/stranote_next` (or a question): stop after the brief. The user starts the work with `/stranote_resume`.
- Called from `/stranote_resume`: run the printed **Claim** command (fill in the time), then continue with Mode A step
  3 onward (worktree, work, UPDATE). REFUSED = someone was faster: run `next.ps1` again.
- "nothing on the board for you": follow steps 6-7 of `stranote-resume` (find new work, else health check).
- The script cannot run (no PowerShell): apply the ladder in `stranote-resume` Mode A step 2 by hand.

Keep `next.ps1` in step with the ladder in `stranote-resume` and with the row parsing in `board.ps1`: a change to one
needs the same change in the other.
