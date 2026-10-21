---
name: stranote-resume
description: Resume or save the Stranote project session, for any agent (Claude Code, Codex, Antigravity, Copilot). Use when the user types /stranote_resume, $stranote-resume, "resume Stranote", /stranote_resume update "<what changed>" or /stranote_resume merge. RESUME picks the next task on the STATE.md board by itself, claims it and starts it in its own worktree without asking; UPDATE records the result; merge merges approved branches.
---

# Stranote session (shared by every agent, several agents at once)

Entry and exit point for **Stranote**. Home folder `D:\Projects\Stranote` (the person's live install is `D:\Work`).
The living state is `D:\Projects\Stranote\STATE.md`, block `## CURRENT STATE`, with a **Task board**. Rules are in
`AGENTS.md`. Several agents may work at the same time: each one on a different board task, in its own worktree.

- no argument -> **Mode A (RESUME)**: pick the next task yourself and start it. `/stranote_resume <task id>` -> that task
- `update "<what changed>"` -> **Mode B (UPDATE)**. Run after every meaningful action and ALWAYS before ending a turn
  that changed project files.
- `merge` -> **Mode C (MERGE)**: the owner's standing "yes" to merge every `approved` row.

Always read the board at the absolute path `D:\Projects\Stranote\STATE.md` (never a worktree copy).
**Change it ONLY with `board.ps1`** (strict no-overwrite rules: section at the end of this file). Never save `STATE.md` with an editor or a
file-write tool. In the commands below `$B` means:
`powershell -NoProfile -ExecutionPolicy Bypass -File D:\Projects\Stranote\.agents\skills\stranote-resume\board.ps1 -Agent "<agent (model)>"`
Exit 1 = REFUSED, nothing written: re-read the board and pick again; never guess `-Expect` to get past it.

**The owner wants zero questions in Mode A.** `/stranote_resume` IS the instruction to choose a task and start it.
Do not ask which task, whether to start, or whether to take something over. The only things you never do on your own:
take a `claimed` row, start a `blocked` row, merge (Mode C only), push, touch `D:\Work`, or change the stack.

## Mode A - RESUME (automatic)
1. Read `STATE.md` (skip it if a session hook already injected it). Do NOT explore the codebase to rebuild context.
2. **Pick a task. Never answer "nothing for me": go down this ladder until a step gives you a task.**
   Run skill `stranote-next` first (`next.ps1 -Agent "<agent (model)>" [-Id <id>]`): it computes steps 1-5 below and
   prints the claim command; use its answer. Apply the ladder by hand only for steps 6-7, or if the script cannot run.
   1. **Named:** the task the user named (`/stranote_resume S2`, or a request in the same message). Claimed by
      another agent -> say so in one line and go on down the ladder.
   2. **A review:** a row in `review` whose Branch is a task branch (`<agent>/<id>`) written by a different agent kind
      than you. Reviews come first because they unblock merges. Agents on a small model (Copilot, or any agent on a
      Flash / mini / small model) review only branches that change docs, skills or pack text; branches that change
      `src/` or `tests/` need Claude or Codex on a strong model.
   3. **Best fit:** the first `open` row (table order = priority) whose Fit names you or says `any`, and whose
      **Touches** do not overlap a `claimed` row.
   4. **Any open row:** the first `open` row you can do even if its Fit names other agents (Fit is advice: say "not
      the best fit"). Rows whose Fit is only `owner` stay with the owner.
   5. **Prepare an owner decision:** the first `blocked: owner` row without a memo -> write
      `docs/decisions/<id>.md` (the question, 2-3 options with cost and risk, your recommendation, what it unblocks) on
      branch `<agent>/<id>-memo`, then set the row to `blocked: owner (memo: <branch>)`. Never decide for the owner.
   6. **Find new work:** look, in this order, at unchecked tasks in `specs/*/tasks.md` not blocked by a board row,
      items in `PHASE_REVIEW.md` marked "fix when the file is next edited", engine functions without a Pester test,
      `TODO`s in `src/`, gaps in `README.md` / `docs/`. Add the smallest useful one as a new board row (next free id,
      Fit, Touches) and claim it. It must stay inside the current rules: no new playbook phase, no Phase A code before
      P3 is approved, no stack change, never `D:\Work`.
   7. **Health check** (only if 1-6 gave nothing): in a detached worktree of `main`, run the full Pester suite and
      check that `STATE.md`, `AGENTS.md` and the skills agree; add every problem as a new `open` row; log the result.
   Always skip `claimed`, `reviewing`, `blocked`, `approved` and `done` rows, including rows claimed under your own
   agent name in an older session (they may still be running). Uncommitted files in the home folder are not a reason
   to stop: you work in your own worktree.
3. **Claim it (FIRST action, before any file change, build or test)** with `board.ps1`:
   - open row: `$B -Id <id> -Expect open -Status claimed -ClaimedBy "<agent (model)> <yyyy-MM-dd HH:mm>" -Branch <agent>/<id>`
   - review: `$B -Id <id> -Expect review -Status reviewing -ClaimedBy "<agent (model)> <time> - reviewing <branch>"`
   - owner memo: `$B -Id <id> -Expect "blocked: owner" -ClaimedBy "<agent (model)> <time> - writing memo" -Branch <agent>/<id>-memo`
   - new work: `$B -NewRow -Id <next free id> -Task "..." -Fit "..." -Touches "..." -Status claimed -ClaimedBy "..." -Branch ...`
   REFUSED (someone was faster, or your Touches overlap a claimed row) -> go back to step 2. Never edit the file by hand.
4. **Worktree** (skip for rows whose Touches say `home`):
   - New work: `& 'C:\Program Files\Git\cmd\git.exe' -C D:\Projects\Stranote worktree add D:\Projects\Stranote-wt\<id> -b <branch> main`
   - Review: `... worktree add --detach D:\Projects\Stranote-wt\<id>-review <branch>` (the author's worktree keeps the branch)
   Do ALL file work there. Files not committed on `main` are not in your worktree: read them from
   `D:\Projects\Stranote\...` by absolute path. Test server: first free port from 8767 (8765 is live, never use it).
   Tests use temp data only. Scratch files (diffs, notes, command output) go to `%TEMP%\stranote-<agent>\`, never
   into the repo or the home folder.
5. Print the brief, then start immediately (no "should I start?"):

---
## Stranote - Session Brief
**My task:** [id - title - branch - worktree path]
**Why this one:** [ladder step: named / review / best fit / any open row / owner-decision memo / new work found in <source> / health check]
**Others working now:** [claimed/reviewing rows: who, which task, since]
**Last completed:** [latest 1-3 log lines]
**Blocked on owner:** [ids only]
---

6. **While working, do not stop to ask.** When something needs the owner's decision, take the most conservative
   option that keeps the work reversible (smaller change, no data change, existing behaviour kept), write the
   question as a new board row `blocked: owner` (Fit `owner`) and continue. Stop early only if the task cannot be done
   without that decision: then set your row back to `blocked: <new row id>` in Mode B. Talk in Egyptian Arabic or
   English as the user writes; keep technical terms in English.

**Doing a review:** read `git diff main...<branch>`, run the full Pester suite in the review worktree, and check the
change against `AGENTS.md`, skill `stranote-dev`, the constitution and the task's text (UI changes: light, dark, 390px). Result:
- good -> `$B -Id <id> -Expect reviewing -Status approved -ClaimedBy "<you> <time>: approved <commit>, tests n/n; <notes>" -Log "..."`
  (note small issues; never change the author's branch);
- problems -> `$B -Id <id> -Expect reviewing -Status open -Task "<task> - fix: <findings>" -ClaimedBy "" -Log "..."`;
  whoever claims the row next owns its branch and worktree and continues there.
Then `git worktree remove D:\Projects\Stranote-wt\<id>-review`.

## Mode B - UPDATE
Change `D:\Projects\Stranote\STATE.md` ONLY with `board.ps1`: your row, one log line, rows you add, shared fields.
Example: `$B -Id <id> -Expect claimed -Status review -ClaimedBy "<you> <time> - done <commit>" -Log "<id> <result> (<branch>, tests n/n)"`
- **Your row:** `review` (done, committed on your task branch, waiting for a review by another agent) with a
  one-line result; or `open` with a note if you stop unfinished (worktree and branch stay; the next agent continues
  there); or `blocked: <id>` if a new owner question stops it. Commit on your task branch before `review`
  (`git commit -F <file>`); never commit to `main` outside Mode C, never push.
- Shared lines above the board: `$B -Field Tests -Value "..."` (also `Phase`, `Working now`, `Uncommitted in home`).
- Rows done in the home folder with nothing to review (docs for the owner, board/rules upkeep) go straight to `done`.
- **Log:** `-Log "<id> <result> (<branch>, tests n/n)"` (the script adds date + agent and keeps the latest 5).
- New work you found -> a new board row (next free id, Fit, Touches, Status `open` or `blocked: <why>`).
- **Tests** line: only if you ran the full suite (count + branch).
- Always-on rules belong in `AGENTS.md`, developer rules (decisions, run/test, file map) in skill `stranote-dev`; change them only when a decision changes.
- Keep the `## CURRENT STATE` heading text exactly (a hook reads it). Hard cap ~90 lines.

Output two lines: "Stranote state updated - <id> is <status>." and the **Agent fit** line of the next open task.

## Mode C - MERGE (only when the owner types `/stranote_resume merge`)
For each `approved` row, in table order, in the home folder `D:\Projects\Stranote` on `main`:
`git merge --no-ff --no-commit <branch>` -> run the full suite on the merged files -> green: `git commit -F <file>`,
row `done` with the merge commit (`$B -Id <id> -Expect approved -Status done -Merge -Log "..."`), then `git worktree remove D:\Projects\Stranote-wt\<id>` and `git branch -d <branch>`.
A conflict or a red suite: `git merge --abort` (never `reset --hard`: the home folder holds uncommitted board edits),
set the row `open` with "fix: merge conflict / failing tests: ..." (`-Merge -Status open`) and continue with the next row. Never push.
After the last row: `$B -Archive` (done rows move to `STATE_HISTORY.md`). Report merged / sent back.

## No-overwrite rules (STRICT, every agent, no exceptions)
Breaking one of these loses another agent's work. If a rule stops you, stop and tell the owner; never work around it.
1. **Board only through `board.ps1`** (`$B` above; examples at the top of the script). Never save `STATE.md` with an
   editor or file tool, never write the whole file, never paste an older copy back. Every row change states what you
   last read (`-Expect <status>`); REFUSED (exit 1) = nothing written: re-read and decide again, never guess `-Expect`.
   `WARNING: STATE.md was changed outside board.ps1` -> tell the owner what it lists; do not repair others' lines.
2. **One row, one holder** (the agent named at the start of Claimed by). Others may only claim an `open` row, take a
   `review` row as `reviewing` (never your own work), add a row, add a log line. `approved`/`done` change only with
   `-Merge` (Mode C) or `-OwnerSaid "<owner's exact words>"`; `blocked: owner` opens only on the owner's word.
3. **Files:** only what your row's Touches lists. A claim overlapping a `claimed` row's files is refused: add your
   work as `blocked: <that id>` and pick something else. Need another file? Add it to your Touches with `board.ps1`
   first. Never work in the worktree of a row you do not hold; never edit or delete files another agent left
   uncommitted in the home folder unless your Touches name them.
4. **Git:** a row's Branch and worktree belong to its current holder (a row sent back to `open` continues on its
   branch with whoever claims it). Commit only there; never commit to, rebase, reset or delete another agent's
   branch; never push. In the home folder never `reset --hard`, `checkout -- <path>`, `restore`, `stash`, `clean`,
   switch branches or `rebase`; merges only in Mode C (`merge --abort` on a conflict). Remove only worktrees and
   branches you created.
5. **Outside the repo:** `D:\Work` only when your row says so, one agent at a time; never port 8765; test ports from
   8767 (check it is free). Before ending a turn that changed project files, run UPDATE; uncommitted home-folder
   work must be listed in `STATE.md` (`-Field "Uncommitted in home"`).

## Agents and "Agent fit"
| Agent | Models | Fits |
|---|---|---|
| Claude Code | Opus 5.5 (default); Sonnet 5.5 routine coding; Haiku 5.5 trivial edits | planning, specs, playbook, product decisions with the owner, multi-file engine work, live upgrade, Arabic teaching content, reviews |
| Codex | gpt-6-luna (xhigh) | multi-file coding, tests, performance work, independent review of another agent's branch |
| Google Antigravity | **paused** (free quota used up, 2026-10-21; owner re-enables) - was Gemini Flash | none while paused: no Fit names it; its UI checks -> Claude Code or Kilo Code, its coding/second review -> Codex. Its Flash model counts as small. |
| Cline (VS Code extension) | the model set in Cline (today MiniMax-M3.1-Flash, small) | one-file fixes, docs, pack JSON text, reviews of docs/skill/pack-text branches only |
| Kilo Code (VS Code extension) | the model set in Kilo (free models, the owner switches them: Nemotron 3.5 Super VL sees images, MiniMax-M3.1-Flash is small); entry `.kilocode/` | one-file fixes, docs, skill text, pack JSON text, one Pester test file, docs/skill/pack-text reviews, UI checks from screenshots (light/dark/390px) |
| GitHub Copilot (VS Code Chat, free plan, Auto model) | small models, monthly limit | one-file fixes (CSS, wording, pack JSON labels), explaining code, one Pester test, read-only review |
| Cursor (free plan, Auto model) | Cursor's Auto model, limited monthly requests, always small in `next.ps1`; entry `.cursor/` | one-file fixes, docs, skill text, pack JSON text, one Pester test file for pure helpers, docs/skill/pack-text reviews; finish one row per session to spend the quota well |

How to choose: owner decision, spec, more than ~3 files, engine PowerShell or `D:\Work` -> Claude Code or Codex.
UI that must be seen in a browser -> Claude Code (Chrome / built-in browser), or Kilo Code from screenshots (light,
dark, 390px). One file with a clear "done" -> Kilo Code, Cline, Cursor or Copilot.
A review -> an agent other than the author. Every board row has a **Fit** column. When you finish a task, end your
reply with the Agent fit line of the next open task:
`**Agent fit:** Claude Code > Opus 5.5 (best) · Codex > gpt-6-luna (ok) · GitHub Copilot (no: needs planning)`
