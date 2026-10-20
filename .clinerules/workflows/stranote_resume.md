# /stranote_resume

Stranote session command, shared by every agent (Claude Code, Codex, Antigravity, Copilot, Cline).

1. Read `D:\Projects\Stranote\.agents\skills\stranote-resume\SKILL.md` and follow it exactly.
2. Text the user typed after the command is its argument: nothing = RESUME (pick, claim and start your next task
   with no questions), a task id = that task, `update "..."` = UPDATE, `merge` = MERGE.
3. Rules: `D:\Projects\Stranote\AGENTS.md`. Board: `D:\Projects\Stranote\STATE.md` (always this absolute path).
4. You are "Cline (<your model>)" on the board. Scratch files go to `%TEMP%\stranote-cline\`, never into the repo.
