Follow `AGENTS.md` at the repo root: it is the shared rulebook for every agent on Stranote (Claude Code, Codex,
GitHub Copilot). Several agents may work at once: before changing any file, claim ONE open row of the Task board in
`D:\Projects\Stranote\STATE.md` whose Fit includes Copilot, and work in your own worktree, exactly as described in
`.agents/skills/stranote-resume/SKILL.md`. Skills referenced there live in `.agents/skills/<name>/SKILL.md`: read the
matching one before the task. To find your next task, run
`.agents\skills\stranote-next\next.ps1 -Agent "GitHub Copilot (<model>)"` (read-only; skill `stranote-next`).

STRICT: change `D:\Projects\Stranote\STATE.md` ONLY with `.agents\skills\stranote-resume\board.ps1` (never save it with an editor or file tool), and follow the "No-overwrite rules" in `.agents/skills/stranote-resume/SKILL.md`. Never edit another agent's row, branch, worktree or uncommitted files.
