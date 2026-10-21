# /stranote_resume

Stranote session command, shared by every agent (Claude Code, Codex, Antigravity, Copilot, Cline, Kilo Code).

1. Read `D:\Projects\Stranote\.agents\skills\stranote-resume\SKILL.md` and follow it exactly.
2. Text the user typed after the command is its argument: nothing = RESUME (pick, claim and start your next task
   with no questions), a task id = that task, `update "..."` = UPDATE, `merge` = MERGE.
3. Rules: `D:\Projects\Stranote\AGENTS.md` and `.kilocode/rules/stranote.md`. Board: `D:\Projects\Stranote\STATE.md`
   (always this absolute path).
4. You are "Kilo Code (<your model>)" on the board; pass `-Small` to `next.ps1`. Scratch files go to
   `%TEMP%\stranote-kilo\`, never into the repo.
5. STRICT: change `D:\Projects\Stranote\STATE.md` ONLY with `.agents\skills\stranote-resume\board.ps1` (never save it with an editor or file tool), and follow the "No-overwrite rules" in `.agents/skills/stranote-resume/SKILL.md`.
