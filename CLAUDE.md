@AGENTS.md

## Claude Code only
- `/stranote_resume` and `/stranote_status` are user commands in `~/.claude/commands` that forward to the shared
  procedures in `.agents/skills/`. The SessionStart hook injects `STATE.md`; the Stop hook asks for UPDATE when
  project files are newer than `STATE.md`.
- The shared skills in `.agents/skills/` reach Claude through junctions in `~/.claude/skills`; edit them in the repo.
