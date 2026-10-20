# Stranote - living state

Shared by every agent. Read by `/stranote_resume` (RESUME/STATUS), rewritten by `/stranote_resume update`.
Rules, run/test, agents and file map are in `AGENTS.md`; history is in `specs/*/tasks.md` and git.

## CURRENT STATE
<!-- Last updated: 2026-10-20 by Claude Code (Opus 5.5) - agent fit labels, Copilot prompts, merged to main -->
**Working now:** free
**Last agent:** Claude Code (Opus 5.5), 2026-10-20. Branch `main` (agent-shared setup merged from
`agent-shared-setup`, not pushed). Uncommitted: only the playbook files (`STRANOTE_LINEAR_PLAYBOOK.md`,
`LOCAL_FIRST_AUDIT.md`, `PHASE_A_NOTES.md`, untracked on purpose).
**Tests:** 113 pass on main (not re-run: no code changed).
**Phase:** rename, GitHub, Linear-style UI, US2, US3 (T031-T038), US4 (T039-T042) done. Now: `STRANOTE_LINEAR_PLAYBOOK.md`
steps 2-4 (review, baseline, Phase A spec).

### Last completed
- Project made agent-shared (Claude Code, Codex, GitHub Copilot): rules `AGENTS.md` (+ `CLAUDE.md`,
  `.github/copilot-instructions.md`), state in this file, procedures + Stranote skills in `.agents/skills/`
  (junctions from `~/.claude/skills`, `~/.codex/skills`), Copilot commands `.github/prompts/stranote_{resume,status}`.
  Codex check passed.
- Rules added: claim first (`Working now`), Agent fit line after every task + `[fit: ...]` tags on open items.

### Next action
Playbook step 2 (no code): read `STRANOTE_LINEAR_PLAYBOOK.md` + `.specify/memory/constitution.md` + `LOCAL_FIRST_AUDIT.md`
+ `specs/001-*` and reply with (a) conflicts with constitution/specs, (b) open items/backlog -> playbook phase map,
(c) what is wrong/unclear for this codebase. Then step 3: run tests + record the section 4 performance baseline (numbers
only, e.g. in `PHASE_BASELINE.md`), then step 4: Phase A spec only (review parked `phase-a-wip` f30150d +
`PHASE_A_NOTES.md`), wait for approval.
**Agent fit:** Claude Code > Opus 5.5 (best) · Codex > gpt-6-luna (ok; step 3 baseline fits it well) · GitHub Copilot (no: long cross-document review)

### Open items / blockers
- [fit: owner] Push `main` to GitHub when happy (repo is public).
- [fit: Claude/Codex] Spec 001 left: US5 T043-T045 (second role), T046 skills read the active pack, T047.
- [fit: owner, then Copilot ok] Brand gaps found 2026-10-20 (owner to pick): logo bar hard-coded `#4F46E5` (does not
  follow accent); CV export hard-codes Oracle red `#C74634`; learn-accent fallback differs (`#4F46E5` in CSS/JS vs
  `#2563EB` default); 3 inline logo copies; fonts from Google CDN; EBS categories Technical/Financial/Business/SCM as
  core fallback.
- [fit: owner, then any] Packs (general, accountant, nurse, developer) list `01_Tasks` that the engine never uses
  (tasks go to `01_Tickets`): remove it or make the tasks folder pack-driven (product decision).
- [fit: Claude/Codex] `skillMap` / `starterLessons` pack fields are not used by the engine yet; `starterLessons` are
  empty in all packs (onboarding first-week plan needs starter lessons).
- [fit: Claude/Codex] T046: `ebs-task`, `ebs-dashboard-guide`, `stranote-learn` skills (in `.agents/skills/`) still
  assume EBS; must read the active pack.
- [fit: Copilot ok] CV warning text for `privateNames` hits says "internal custom object names" (fits EBS, not nurse
  patient ids): make it pack-driven.
- [fit: Copilot ok] UI nit: dark mode board horizontal scrollbar track renders white (template CSS, not pack).
- [fit: any] Design follow-ups (optional, spec section 13): right-click context menu on rows/cards, styled tooltips
  instead of `title`.
- [fit: owner] T-0001 EBS screenshots pending from the user.
