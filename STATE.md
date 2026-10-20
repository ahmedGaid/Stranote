# Stranote - living state

Shared by every agent. Read by `/stranote_resume` (RESUME/STATUS), rewritten by `/stranote_resume update`.
Rules, run/test, agents and file map are in `AGENTS.md`; history is in `specs/*/tasks.md` and git.
Several agents can work at once: each claims ONE board row and works in its own worktree
(`D:\Projects\Stranote-wt\<id>`, branch `<agent>/<id>`). Procedure: `.agents/skills/stranote-resume/SKILL.md`.

## CURRENT STATE
<!-- Last updated: 2026-10-20 17:20 by Claude Code (Opus 5.5) - automatic task picking (X2) -->
**Working now:** free
**Phase:** US4 (T039-T042) done. Playbook: server baseline + Phase A spec (`specs/002-phase-a-safety/`) drafted by
Codex; Phase A waits for owner approval of its scope.
**Tests:** 113 pass, 0 fail, 0 skipped on main (Codex, 2026-10-20). Candidate phase-a-wip f30150d not run.
**Performance:** P1 complete: 100 synthetic duties; cold GET / 3072.71 ms, warm median/p95 1401.69/1560.20 ms;
full page 593079 bytes (template 283409; combined inline JSON 309727). Headless Edge metrics and limits are in
PHASE_BASELINE.md; status POST confirmation was 14519.50 ms.
**Uncommitted in home** (not in worktrees until committed): `.specify/feature.json` (active spec -> 002),
`PHASE_BASELINE.md`, `specs/002-phase-a-safety/`, `STRANOTE_LINEAR_PLAYBOOK.md`, `LOCAL_FIRST_AUDIT.md`,
`PHASE_A_NOTES.md`, Codex scratch `_tmp_*.txt` (Codex to delete), `tests/perf/` (P1). Task-board rules and
`PHASE_REVIEW.md` are committed on main.

### Task board
Status: `open` · `claimed` · `review` (done on its branch, any other agent reviews it next) · `reviewing` ·
`approved` (owner: `/stranote_resume merge`) · `done` · `blocked: <why>`. Order = priority. Touches `home` = edit in
`D:\Projects\Stranote`, no worktree. `/stranote_resume` picks automatically and never answers "nothing": named > review > best fit > any
open row > owner-decision memo > new work from the backlog > health check.

| ID | Task | Fit | Status | Claimed by | Branch | Touches |
|---|---|---|---|---|---|---|
| P1 | Complete PHASE_BASELINE.md: method, template vs data bytes, browser metrics via headless Edge, full Pester run; result: 100-duty baseline, 113/0/0 Pester; old temp cleanup blocked by automatic review | Codex | done | Codex (gpt-6-luna) 2026-10-20 15:49 - complete | main (home, before the board) | home: PHASE_BASELINE.md, tests/perf/ |
| P2 | Playbook step 2 written up in `PHASE_REVIEW.md`: (a) conflicts with constitution/specs, (b) backlog -> playbook phase map, (c) unclear points + EBS-specific names list for Phase I (playbook section 10.3) | Claude Opus, Codex | done | Claude Code (Opus 5.5) 2026-10-20 16:12 - 4 conflicts, phase map, 6 unclear points, EBS names list; owner decisions in D3-D5 | main (home) | home: PHASE_REVIEW.md |
| X3 | `/stranote_resume` never answers "nothing for me" (fallback ladder); Cline in agents table; scratch files out of the repo | Claude Opus | done | Claude Code (Opus 5.5) 2026-10-20 17:08 - rules committed to main | main (home) | home: .agents/skills/stranote-resume, AGENTS.md, .gitignore, STATE.md |
| X1 | Add Google Antigravity as a 4th agent (global skills + rules, AGENTS.md agents table, board Fit) | Claude Opus | done | Claude Code (Opus 5.5) 2026-10-20 16:35 - done; owner to run the Antigravity check | main (home, uncommitted) | home: AGENTS.md, STATE.md; ~/.gemini |
| X2 | `/stranote_resume` picks and starts the next task with no questions (auto reviews, `approved` status, `/stranote_resume merge`) | Claude Opus | done | Claude Code (Opus 5.5) 2026-10-20 17:10 - rules committed to main | main (home) | home: .agents/skills/stranote-resume, AGENTS.md, STATE.md |
| P3 | Approve Phase A scope in `specs/002-phase-a-safety/spec.md` (Explorer edits, stale browser saves, multi-file atomicity) | owner | blocked: owner | | | |
| P4 | Forward-port `phase-a-wip` f30150d onto main incl. T040-T042 pack-request/custom-pack writes + tests | Claude Opus, Codex, Antigravity | blocked: P3 | | | src/*.ps1 writers, tests/ |
| P5 | Reconcile playbook Phase C change journal with the anti-goal "no single-PC sync log" | owner | blocked: owner | | | |
| D3 | Decide: Spec 001 remainder now or after Phase A (`PHASE_REVIEW.md` C4; recommendation S2 now, S1 after Phase A) | owner | blocked: owner | | | |
| D4 | Decide how to mark unreviewed packs (accountant, nurse, developer, EBS functional) + who reviews them (C3) | owner, then any | blocked: owner | | | packs/*.json, onboarding |
| D5 | Constitution §III: neutral write header instead of `X-EBS` (C2; can wait for Phase I); and what "inline payload < 150 KB" measures (U2) | owner | blocked: owner | | | |
| S1 | Spec 001 US5 T043-T045: second role / role switching | Claude Opus, Codex, Antigravity | blocked: D3 | | | src/StranotePacks.ps1, src/StranoteOnboarding.ps1, src/dashboard_template.html, tests/ |
| S2 | T046: `ebs-task`, `ebs-dashboard-guide`, `stranote-learn` skills read the active pack | Claude Opus, Codex, Antigravity | reviewing | Cline (MiniMax-M3.1-Flash) 2026-10-20 16:56 - reviewing claude/S2 (12f5f6c + f544e51) | claude/S2 (review wt: D:\Projects\Stranote-wt\S2-review) | .agents/skills/ |
| S3 | T047 docs + T049 release checks/results for Spec 001 | any | blocked: S1, S2 | | | docs/, specs/001-*/ |
| U1 | Dark mode: board horizontal scrollbar track renders white | Antigravity (best: browser check), Copilot ok, any | claimed | Antigravity (Gemini 3.8 Flash) 2026-10-20 16:18 | antigravity/U1 | src/dashboard_template.html (CSS) |
| U2 | CV `privateNames` warning text pack-driven (now says "internal custom object names") | Antigravity (best: browser check), Copilot ok, any | open | | | src/dashboard_template.html, packs/*.json |
| E1 | Engine uses pack `skillMap` / `starterLessons`; starter lessons are empty in all packs | Claude Opus, Codex, Antigravity | blocked: needs spec | | | src/StranoteLearn.ps1, packs/ |
| D1 | Decide `01_Tasks` (listed by packs, unused) vs `01_Tickets` | owner | blocked: owner | | | |
| D2 | Brand gaps: logo bar `#4F46E5` ignores accent, CV export Oracle red, learn-accent fallback, 3 inline logos, Google Fonts, EBS categories fallback | owner, then any | blocked: owner | | | |
| E2 | Optional: right-click context menu, styled tooltips (spec 001 section 13) | Antigravity, any | open | | | src/dashboard_template.html |
| O1 | T-0001 EBS screenshots | owner | blocked: owner | | | |

### Log (latest first, max 8)
- 2026-10-20 Claude Code: X3 pick ladder (named > review > best fit > any open > owner memo > new work > health check; never "nothing"); Cline added (small model: no code reviews); scratch files to %TEMP%, `_tmp_*` git-ignored.
- 2026-10-20 Codex: P1 complete: reproducible 100-duty baseline, page/data split, headless Edge timings; Pester 113/0/0. Recursive cleanup of old temp dirs was blocked by automatic review (main).
- 2026-10-20 Claude Code: X2 `/stranote_resume` is fully automatic (named task > review of another agent's branch > first open row; owner questions become `blocked: owner` rows); new statuses `reviewing`/`approved`; `/stranote_resume merge`; board rules committed to main.
- 2026-10-20 Claude Code: S2/T046 done: 3 skills read the active pack (EBS rules only for `oracle-ebs-*`), checked on temp data with the nurse pack (claude/S2 12f5f6c + f544e51, tests 113/113).
- 2026-10-20 Claude Code: X1 Antigravity added (reads AGENTS.md + `.agents/skills/` natively; global skills `~/.gemini/config/skills` junctions, rules `~/.gemini/GEMINI.md` -> `~/.claude/CLAUDE.md`); Fit columns updated.
- 2026-10-20 Claude Code: P2 review -> `PHASE_REVIEW.md` (4 conflicts, backlog->phase map, 6 unclear points, EBS names in core); added owner rows D3-D5 (home, uncommitted).
- 2026-10-20 Claude Code: task board for parallel agents (claim a row + own worktree), replaces single "Working now".
- 2026-10-20 Codex: playbook review notes, Pester 113/0/0, server baseline, drafted `specs/002-phase-a-safety/spec.md`.
- 2026-10-20 Claude Code: agent-shared setup (AGENTS.md, STATE.md, `.agents/skills/`, Copilot prompts) merged to main c0c0aa2.
