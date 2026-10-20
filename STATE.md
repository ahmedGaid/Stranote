# Stranote - living state

Shared by every agent. Read by `/stranote_resume` (RESUME/STATUS), rewritten by `/stranote_resume update`.
Rules, run/test and file map are in `AGENTS.md`; history is in `specs/*/tasks.md` and git.

## CURRENT STATE
<!-- Last updated: 2026-10-20 by Claude Code (Opus 5.5) - agent-shared setup -->
**Working now:** free
**Last agent:** Claude Code (Opus 5.5), 2026-10-20. Agent-shared setup committed on branch `agent-shared-setup` (not
merged, not pushed). Uncommitted: only the playbook files (`STRANOTE_LINEAR_PLAYBOOK.md`, `LOCAL_FIRST_AUDIT.md`,
`PHASE_A_NOTES.md`, untracked on purpose).
**Tests:** 113 pass on main.
**Phase:** rename, GitHub, Linear-style UI, US2, US3 (T031-T038), US4 (T039-T042) done. Now: `STRANOTE_LINEAR_PLAYBOOK.md`
steps 2-4 (review, baseline, Phase A spec).

### Last completed
- Made the project agent-shared (Claude Code, Codex, others): rules in `AGENTS.md` (+ `CLAUDE.md` imports it), state
  moved here from `~/.claude/commands/stranote_resume.md`, session procedures + Stranote skills moved to
  `.agents/skills/` (junctions from `~/.claude/skills` and `~/.codex/skills`), Codex global rules
  `~/.codex/AGENTS.md` point to `~/.claude/CLAUDE.md`, hook registry `~/.claude/hooks/projects.json` reads this file.
  Codex check passed (sees AGENTS.md, all shared skills, `$stranote-status`).
- Claim rule: every agent writes `**Working now:**` in this file before starting any task, releases it in UPDATE.
- Spec 001 US4 done, pushed and live: T040 1305e1a+f8cb15f, T041 d161cc4, T042 e9e0c92. 113 tests pass.

### Next action
Playbook step 2 (no code): read `STRANOTE_LINEAR_PLAYBOOK.md` + `.specify/memory/constitution.md` + `LOCAL_FIRST_AUDIT.md`
+ `specs/001-*` and reply with (a) conflicts with constitution/specs, (b) open items/backlog -> playbook phase map,
(c) what is wrong/unclear for this codebase. Then step 3: run tests + record the section 4 performance baseline (numbers
only, e.g. in `PHASE_BASELINE.md`), then step 4: Phase A spec only (review parked `phase-a-wip` f30150d +
`PHASE_A_NOTES.md`), wait for approval.

### Open items / blockers
- Owner: merge branch `agent-shared-setup` into `main` and push when happy (repo is public).
- Spec 001 left: US5 T043-T045 (second role), T046 skills read the active pack, T047.
- Brand gaps found 2026-10-20 (not fixed, owner to pick): logo bar hard-coded `#4F46E5` (does not follow accent); CV
  export hard-codes Oracle red `#C74634`; learn-accent fallback differs (`#4F46E5` in CSS/JS vs `#2563EB` default);
  3 inline logo copies; fonts from Google CDN; EBS categories Technical/Financial/Business/SCM as core fallback.
- Packs (general, accountant, nurse, developer) list `01_Tasks` that the engine never uses (tasks go to `01_Tickets`):
  remove it or make the tasks folder pack-driven (product decision).
- `skillMap` / `starterLessons` pack fields are not used by the engine yet; `starterLessons` are empty in all packs
  (onboarding first-week plan needs starter lessons).
- T046: `ebs-task`, `ebs-dashboard-guide`, `stranote-learn` skills (now in `.agents/skills/`) still assume EBS; must
  read the active pack.
- CV warning text for `privateNames` hits says "internal custom object names" (fits EBS, not nurse patient ids): make
  it pack-driven.
- UI nit: dark mode board horizontal scrollbar track renders white (template CSS, not pack).
- Design follow-ups (optional, spec section 13): right-click context menu on rows/cards, styled tooltips instead of `title`.
- User-side (not code): T-0001 EBS screenshots pending from the user.
