# Stranote - rules for every agent

Shared rulebook for any coding agent working on Stranote (Claude Code, Codex, or another). Claude Code loads it through
`CLAUDE.md`; Codex reads it directly. It wins over your tool's defaults. The constitution
(`.specify/memory/constitution.md`) wins over this file; the owner can change either one in writing.

Stranote turns anyone's daily work (any career) into lasting knowledge: tasks -> auto knowledge cards -> teach before
quiz (Egyptian Arabic) -> daily spaced review -> skills/CV. Started as an Oracle EBS tool, now career packs.
GitHub (public): https://github.com/ahmedGaid/Stranote.git

## Where everything lives (one copy each, shared by all agents)
| What | Where |
|---|---|
| Living plan state: phase, last completed, next action, open items, last agent | `STATE.md` |
| Rules, run/test, file map | `AGENTS.md` (this file) |
| Spec, plan, task list + history | `specs/001-career-packs-onboarding/` (`tasks.md`) |
| Principles | `.specify/memory/constitution.md` |
| Standing brief | `STRANOTE_LINEAR_PLAYBOOK.md` + `LOCAL_FIRST_AUDIT.md` |
| Shared skills | `.agents/skills/<name>/SKILL.md`, Spec Kit in `.claude/skills/speckit-*/SKILL.md` |

Never keep project facts only in a private agent memory (Claude memory, Codex memories): put them in `STATE.md`, this
file or a skill, so the next agent sees them. The repo is public: no secrets, client names or personal data in it.

## Session commands (same meaning in every agent)
| The user types | Means | Procedure |
|---|---|---|
| `/stranote_resume` (Codex: also `$stranote-resume`) | RESUME: brief + start the Next action | `.agents/skills/stranote-resume/SKILL.md` |
| `/stranote_resume update "<what changed>"` | UPDATE: rewrite `STATE.md` | same file |
| `/stranote_status [focus]` (Codex: also `$stranote-status`) | STATUS: read-only report | `.agents/skills/stranote-status/SKILL.md` |

If your agent does not run these as commands, treat the typed text as the request and follow the procedure file.
GitHub Copilot gets the same commands from `.github/prompts/*.prompt.md`.

**Hand-off (any agent can take the lead):**
- **Claim first:** before starting ANY task here (changing files, running builds/tests), write the
  `**Working now:**` line in `STATE.md` (agent, task, start time, branch). If another agent or session holds it, do not
  start: ask the user. Release it (`free`) in UPDATE. Full rule: `.agents/skills/stranote-resume/SKILL.md`.
- One agent at a time in `D:\Projects\Stranote`. To work in parallel, the second agent uses its own git worktree and
  branch (`git worktree add D:\Projects\Stranote-<agent> -b <agent>/<task>`), never the same folder.
- Before ending any turn that changed project files, run UPDATE (Claude Code has a Stop hook that forces it; other
  agents must do it themselves). Uncommitted work must be listed in `STATE.md`, so the next agent knows what it is.
- Only one agent at a time does the live upgrade of `D:\Work`, and only when the task says so.
- A new procedure used twice becomes a skill in `.agents/skills/` (shared), not a private one.

## Agents on this project and "Agent fit"
| Agent | Models | Fits |
|---|---|---|
| Claude Code | Opus 5.5 (default); Sonnet 5.5 routine coding; Haiku 5.5 trivial edits | planning, specs, playbook, product decisions with the owner, multi-file engine work, live upgrade, Arabic teaching content |
| Codex | gpt-6-luna (xhigh) | multi-file coding, tests, performance work, independent review of another agent's branch |
| GitHub Copilot (VS Code Chat, free plan, Auto model) | small models, monthly limit | one-file fixes (CSS, wording, pack JSON labels), explaining code, one Pester test, read-only review |

How to choose: needs an owner decision, a spec, more than ~3 files, engine PowerShell or `D:\Work` -> Claude Code or
Codex (strongest model). One file with a clear "done" -> Copilot is fine. A review -> an agent other than the author.

**Rule:** whenever you finish a task (or write a Next action / new open item), state which agent fits the NEXT task,
in your reply and in `STATE.md`, in this format:
`**Agent fit:** Claude Code > Opus 5.5 (best) · Codex > gpt-6-luna (ok) · GitHub Copilot (no: needs planning)`
Open items in `STATE.md` carry a short tag: `[fit: Claude/Codex]`, `[fit: any]`, `[fit: Copilot ok]`, `[fit: owner]`.

## Skills (use the skill when its task comes up)
Your agent may load these on its own. If not, open the SKILL.md and follow it before the task. "Load skill X" anywhere
means: read and follow X. Skills written with Claude tool names (AskUserQuestion, Write tool) mean your equivalent:
ask in chat, write the file as UTF-8 without BOM.

| Skill | When |
|---|---|
| `stranote-resume`, `stranote-status` | session commands above |
| `powershell51-gotchas` | BEFORE writing or debugging any PowerShell here (JSON arrays, encodings, Arabic text) |
| `stranote-pack-builder` | draft a career pack from a "My career is not listed" request |
| `stranote-learn` | knowledge cards, quizzes, lessons, Arabic explanations, CV bullets in the user's Stranote |
| `ebs-task` | create/update/list the user's EBS tasks in `D:\Work` |
| `ebs-dashboard-guide` | after any Oracle EBS deliverable: the "Record it on your dashboard" section |
| `speckit-*` (`.claude/skills/`) | Spec Kit flow: specify -> clarify -> plan -> tasks -> analyze -> implement |
| `learning-rules` (user-level, both agents) | before teaching, explaining or quizzing the user (Egyptian Arabic, teach before quiz) |

## Working rules (locked decisions)
- Spec Kit flow; constitution has 7 principles: packs not code, teach-before-quiz, local-first / no secrets in the
  frontend, never lose progress, own language, test the engine + see the UI, simple stack.
- Stack stays: Windows PowerShell 5.1 + HttpListener + one HTML template + JSON. New runtime, framework or service:
  stop and ask the owner.
- Playbook: one phase at a time: spec -> owner approval -> build -> tests -> `PHASE_<X>_NOTES.md`; follow its
  Definition of Done (section 7). Agreed order (2026-10-20): playbook review (no code) -> test run + section 4
  performance baseline (numbers only) -> Phase A spec only, then wait for approval.
- Phase A candidate code is parked on local branch `phase-a-wip` (f30150d, not pushed) + `PHASE_A_NOTES.md`. Review
  it in the Phase A spec; do not merge before approval.
- Naming: functions `Verb-Sn*` (old `Verb-Ebs*/Verb-Ops*` kept as aliases in generated `src/StranoteAliases.ps1`,
  exported by `Stranote.psm1`); env `STRANOTE_{CONFIG,ROOT,LEARN_DIR,PACKS_DIR,NO_SCHEDULE}` (old `OPS_*` copied in at
  load); old-name wrappers `Ops.psm1`, `EbsTasks.psm1`, `EbsServer.ps1`, `OpsServer.ps1`, `EbsMenu.ps1`,
  `Start-OpsMorning.ps1`. Learn dir falls back to `04_Knowledge\Ops` if `Stranote` is missing (`Get-SnLearnDirFor`).
  Kept on purpose: skill names `ebs-task`/`ebs-dashboard-guide`, pack `oracle-ebs-technical`, localStorage `ebsView`,
  header `X-EBS`, card/question ids.
- Settings = `src/settings.default.json` <- active pack (`packs/<id>.json`) <- `overrides.json`; `profile.json`
  (roles -> packId); both in the learn dir. EBS specifics live in `packs/oracle-ebs-technical.json`.
- Dashboard wording comes from pack field `ui` (documented in `contracts/pack-schema.md`), sent as `META.pack`; the
  template keeps only neutral defaults. A Pester gate fails if EBS words come back into the template.
- Custom packs live in `<learn dir>\packs` (read first by `Get-SnPacksDirs`). Pack requests:
  `<learn dir>\pack-requests\<slug>.json`, status pending -> drafted -> accepted|rejected.
- Tests never touch real data: `tests/StranoteTestHelpers.ps1` (temp `STRANOTE_CONFIG` + `STRANOTE_LEARN_DIR`);
  fixture `tests/fixtures/ebs-legacy` keeps the legacy `04_Knowledge\Ops` layout on purpose (do not rename).
- Brand: logo "rising layers" (top bar indigo `#4F46E5`), files `src/brand/stranote-*` + `stranote.ico`. Accent
  indigo, learn accent `#2563EB`; the live app overrides both to Graphite `#3F3F46` (overrides.appearance).
- UI follows `docs/design/LINEAR_INSPIRED_UI_UX.md` (section 0: product brand/terms/workflows win; only look and feel
  changes). Check UI changes in light, dark and 390px width.
- Live upgrade = back up, copy `src\*` (except config/settings json) + `packs\` into `D:\Work\05_Tools\Stranote`,
  restart the server. Backups go to `D:\Work\06_Admin\Backups\stranote-upgrade-<timestamp>`.
- Commit or push only when the owner asks. Mark finished tasks `[X]` in `tasks.md` with the commit id.

## Run and test
- Live: `D:\Work\stranote.cmd` -> http://localhost:8765 (do not use 8765 for testing). Live install
  `D:\Work\05_Tools\Stranote` (junction `05_Tools\EbsTasks`), data `D:\Work\04_Knowledge\Stranote`.
- Dev server: `powershell -ExecutionPolicy Bypass -File src\StranoteServer.ps1 -Port 8766 -Config <temp config.json>`
  with `STRANOTE_NO_SCHEDULE=1`. A second agent working at the same time uses port 8767.
- Tests: `powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Pester D:\Projects\Stranote\tests"`
  (Pester 3.4; run in a fresh process). Count on main: see `STATE.md`.
- Execution policy is Restricted: always `-ExecutionPolicy Bypass`. No python on this PC.
- Git is not on the PowerShell PATH: `& 'C:\Program Files\Git\cmd\git.exe'`. Commit messages: write a file and
  `git commit -F <file>`.

## File map
- `src/StranoteCore.ps1` core (tasks, settings, config, env fallback, exports `$script:SnExports`) · `src/Stranote.psm1`
- `src/StranotePacks.ps1` packs/profile/overrides · `src/StranoteMigrate.ps1` migration + snapshots
- `src/StranoteLearn.ps1` cards, auto knowledge, questions, CV, Arabic, `Get-LearnDir`/`Get-SnLearnDirFor`
- `src/StranoteTeach.ps1` lessons/follow-ups · `src/StranoteReview.ps1` daily review · `src/StranoteOnboarding.ps1`
- `src/StranoteServer.ps1` HTTP API · `src/Start-StranoteMorning.ps1` · `src/StranoteMenu.ps1` · `src/StranoteAliases.ps1`
- `src/dashboard_template.html` whole UI · `packs/*.json` · `tests/*.Tests.ps1` · `specs/001-*/*` · `docs/`
