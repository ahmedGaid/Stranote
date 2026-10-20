# Stranote - living state

Shared by every agent. Read by `/stranote_resume` (RESUME/STATUS), rewritten by `/stranote_resume update`.
Always-on rules: `AGENTS.md`; board procedure + no-overwrite rules: skill `stranote-resume`; code rules: skill `stranote-dev`; finished rows: `STATE_HISTORY.md`.
Several agents can work at once: each claims ONE board row and works in its own worktree
(`D:\Projects\Stranote-wt\<id>`, branch `<agent>/<id>`). Procedure: `.agents/skills/stranote-resume/SKILL.md`.

## CURRENT STATE
<!-- Last updated: 2026-10-20 18:03 by Claude Code (Opus 5.5) - new row X8 (claimed) -->
**Working now:** free
**Phase:** US4 (T039-T042) done. Playbook: server baseline + Phase A spec (`specs/002-phase-a-safety/`) drafted by
Codex; Phase A waits for owner approval of its scope.
**Tests:** 113 pass, 0 fail, 0 skipped on copilot/E2 (GitHub Copilot, 2026-10-20). Candidate phase-a-wip f30150d not run.
**Performance:** P1 complete: 100 synthetic duties; cold GET / 3072.71 ms, warm median/p95 1401.69/1560.20 ms;
full page 593079 bytes (template 283409; combined inline JSON 309727). Headless Edge metrics and limits are in
PHASE_BASELINE.md; status POST confirmation was 14519.50 ms.
**Uncommitted in home** (not in worktrees until committed): `.specify/feature.json` (active spec -> 002), `PHASE_BASELINE.md`, `specs/002-phase-a-safety/`, `STRANOTE_LINEAR_PLAYBOOK.md`, `LOCAL_FIRST_AUDIT.md`, `PHASE_A_NOTES.md`, Codex scratch `_tmp_*.txt` (Codex to delete), `tests/perf/` (P1); X5+X6 rules: `AGENTS.md`, `.agents/skills/stranote-resume/` (SKILL.md, board.ps1), `.agents/skills/stranote-dev/`, `STATE_HISTORY.md`, `CLAUDE.md`, `.gitignore`, `.clinerules/workflows/stranote_resume.md`, `.github/` (copilot-instructions, resume prompt).

### Task board
Status: `open` · `claimed` · `review` (done on its branch, any other agent reviews it next) · `reviewing` ·
`approved` (owner: `/stranote_resume merge`) · `done` · `blocked: <why>`. Order = priority. Touches `home` = edit in
`D:\Projects\Stranote`, no worktree. `/stranote_resume` picks automatically and never answers "nothing": named > review > best fit > any
open row > owner-decision memo > new work from the backlog > health check.

| ID | Task | Fit | Status | Claimed by | Branch | Touches |
|---|---|---|---|---|---|---|
| P3 | Approve Phase A scope in `specs/002-phase-a-safety/spec.md` (Explorer edits, stale browser saves, multi-file atomicity) | owner | blocked: owner (memo: claude/P3-memo) | Claude Code (Opus 5.5) 2026-10-20 17:20 - memo 8dfc9ff: options A/B/C, recommends B; owner replies "P3: A/B/C" | claude/P3-memo (D:\Projects\Stranote-wt\P3-memo) | docs/decisions/P3.md |
| P4 | Forward-port `phase-a-wip` f30150d onto main incl. T040-T042 pack-request/custom-pack writes + tests | Claude Opus, Codex, Antigravity | blocked: P3 | | | src/*.ps1 writers, tests/ |
| P5 | Reconcile playbook Phase C change journal with the anti-goal "no single-PC sync log" | owner | blocked: owner | | | |
| D3 | Decide: Spec 001 remainder now or after Phase A (`PHASE_REVIEW.md` C4; recommendation S2 now, S1 after Phase A) | owner | blocked: owner | | | |
| D4 | Decide how to mark unreviewed packs (accountant, nurse, developer, EBS functional) + who reviews them (C3) | owner, then any | blocked: owner | | | packs/*.json, onboarding |
| D5 | Constitution §III: neutral write header instead of `X-EBS` (C2; can wait for Phase I); and what "inline payload < 150 KB" measures (U2) | owner | blocked: owner | | | |
| S1 | Spec 001 US5 T043-T045: second role / role switching | Claude Opus, Codex, Antigravity | blocked: D3 | | | src/StranotePacks.ps1, src/StranoteOnboarding.ps1, src/dashboard_template.html, tests/ |
| S2 | T046: `ebs-task`, `ebs-dashboard-guide`, `stranote-learn` skills read the active pack | Claude Opus, Codex, Antigravity | reviewing | Cline (MiniMax-M3.1-Flash) 2026-10-20 16:56 - reviewing claude/S2 (12f5f6c + f544e51) | claude/S2 (review wt: D:\Projects\Stranote-wt\S2-review) | .agents/skills/ |
| S3 | T047 docs + T049 release checks/results for Spec 001 | any | blocked: S1, S2 | | | docs/, specs/001-*/ |
| U1 | Dark mode: board horizontal scrollbar track renders white | Antigravity (best: browser check), Copilot ok, any | review | Antigravity (Gemini 3.8 Flash) 2026-10-20 17:18 - done: 04ac1ce, tests 113/113, Edge CDP light/dark/390px (row restored by Claude Code on owner's ok after a stale overwrite) | antigravity/U1 | src/dashboard_template.html (CSS) |
| U2 | CV `privateNames` warning text pack-driven (now says "internal custom object names") | Antigravity (best: browser check), Copilot ok, any | approved | Codex (gpt-6-luna) 653c319; reviewed by Claude Code (Opus 5.5) 2026-10-20 17:15: good, tests 113/113, warning text escaped, neutral fallback; note: pack-builder skill ui list lacks `privateNamesWarning`; no browser check (text only) | codex/U2 (D:\Projects\Stranote-wt\U2) | src/dashboard_template.html, packs/*.json |
| E1 | Engine uses pack `skillMap` / `starterLessons`; starter lessons are empty in all packs | Claude Opus, Codex, Antigravity | blocked: needs spec | | | src/StranoteLearn.ps1, packs/ |
| D1 | Decide `01_Tasks` (listed by packs, unused) vs `01_Tickets` | owner | blocked: owner | | | |
| D2 | Brand gaps: logo bar `#4F46E5` ignores accent, CV export Oracle red, learn-accent fallback, 3 inline logos, Google Fonts, EBS categories fallback | owner, then any | blocked: owner | | | |
| E2 | Optional: right-click context menu, styled tooltips (spec 001 section 13) | Antigravity, any | review | GitHub Copilot (Copilot SDK in VS Code) 2026-10-20 17:05 - 8faf75d; Pester 113/113, UI checked light/dark/390px | copilot/E2 (D:\Projects\Stranote-wt\E2) | src/dashboard_template.html |
| O1 | T-0001 EBS screenshots | owner | blocked: owner | | | |
| X8 | Commit X5-X7 rules to main (owner said ok); compact global ~/.claude/CLAUDE.md | Claude Opus | claimed | Claude Code (Opus 5.5) 2026-10-20 18:10 | main (home) | home: git main commit; ~/.claude/CLAUDE.md |

### Log (latest first, max 5)
- 2026-10-20 Claude Code: X7 AGENTS.md + CLAUDE.md compacted (same rules) (home, uncommitted)
- 2026-10-20 Claude Code: X6 slimmed: AGENTS.md keeps only always-on rules; code rules/run-test/file map -> skill stranote-dev; agents table + no-overwrite rules -> stranote-resume; done rows -> STATE_HISTORY.md (home, uncommitted)
- 2026-10-20 Claude Code: X5 strict no-overwrite rules (AGENTS.md) + board.ps1: only way to change STATE.md (lock, -Expect compare-and-swap, holder-only rows, Touches overlap refused, backups in %TEMP%\stranote-board, warns on outside edits) (home, uncommitted)
- 2026-10-20 Antigravity: U1 fixed dark mode board horizontal scrollbar white track (antigravity/U1 04ac1ce, tests 113/113; Edge CDP verified light/dark/390px). [restored after a stale overwrite]
- 2026-10-20 GitHub Copilot: E2 task context menu and styled tooltips (copilot/E2 8faf75d, Pester 113/113; browser light/dark/390px).
