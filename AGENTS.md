# Stranote - rules for every agent

Read by every agent (Claude via `CLAUDE.md`; Codex, Copilot, Cline directly). Wins over tool defaults;
the constitution (`.specify/memory/constitution.md`) wins over it. Public repo: no secrets, client names or personal data.

## Where things are
- Board, phase, log: `STATE.md` (finished rows: `STATE_HISTORY.md`)
- Board procedure, agents + Agent fit, no-overwrite rules: skill `stranote-resume`
- Code rules, run/test, file map: skill `stranote-dev`
- Specs `specs/<feature>/` · brief `STRANOTE_LINEAR_PLAYBOOK.md` + `LOCAL_FIRST_AUDIT.md`
- Shared skills `.agents/skills/<name>/SKILL.md` · Spec Kit `.claude/skills/speckit-*/SKILL.md`

## Commands
`/stranote_resume` [`<id>` | `update "..."` | `merge`] · `/stranote_status` · `/stranote_next` (read-only: your next task)
(Codex: `$stranote-resume`, `$stranote-status`, `$stranote-next`). Next task for any agent, any day, one command:
`powershell -NoProfile -ExecutionPolicy Bypass -File D:\Projects\Stranote\.agents\skills\stranote-next\next.ps1 -Agent "<agent (model)>"`
(skill `stranote-next`).
No command support: follow `.agents/skills/stranote-resume/SKILL.md`.

## STRICT (every agent, every session)
1. Claim a board row before ANY file change, build or test.
2. Change `STATE.md` ONLY with `.agents\skills\stranote-resume\board.ps1`.
3. Only your row, your Touches files, your worktree (`D:\Projects\Stranote-wt\<id>`), your branch. Never push. In the
   home folder never `reset --hard`, `checkout --`, `restore`, `stash`, `clean`, switch branches or `rebase`.
4. Before touching `src/`, `tests/`, `packs/`, `docs/`, `specs/` or `D:\Work`: load `stranote-dev`. Before
   PowerShell: load `powershell51-gotchas`.
5. Project facts go in `STATE.md` or a shared skill, never only in private memory. Scratch files:
   `%TEMP%\stranote-<agent>\`. A procedure used twice becomes a shared skill.

## Other skills
"Load skill X" = read and follow `X/SKILL.md` (Claude tool names = your equivalent; write files UTF-8 without BOM).
`stranote-pack-builder` draft a career pack · `stranote-learn` cards, quizzes, lessons, CV · `ebs-task` /
`ebs-dashboard-guide` the user's EBS work in `D:\Work` · `speckit-*` spec flow · `learning-rules` before teaching or
quizzing the user.
