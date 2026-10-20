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

Always read and write the board at the absolute path `D:\Projects\Stranote\STATE.md` (never a worktree copy).

**The owner wants zero questions in Mode A.** `/stranote_resume` IS the instruction to choose a task and start it.
Do not ask which task, whether to start, or whether to take something over. The only things you never do on your own:
take a `claimed` row, start a `blocked` row, merge (Mode C only), push, touch `D:\Work`, or change the stack.

## Mode A - RESUME (automatic)
1. Read `STATE.md` (skip it if a session hook already injected it). Do NOT explore the codebase to rebuild context.
2. **Pick, in this order, the first that fits** (your agent name/kind must be in the row's **Fit**, or Fit says `any`):
   1. The task the user named (`/stranote_resume S2`, or a request in the same message). If it is claimed by another
      agent, say so in one line and fall through to the next rule.
   2. **A review:** a row in `review` whose Branch is a task branch (`<agent>/<id>`) and whose author is a different
      agent kind than you. Reviews come first because they unblock merges.
   3. **New work:** the first row in `open` (table order = priority) whose **Touches** do not overlap any `claimed` row.
   Skip every `claimed`, `blocked`, `approved` and `done` row, including rows claimed under your own agent name in an
   older session (they may still be running). Uncommitted files in the home folder are not a reason to stop: you work
   in your own worktree.
   Nothing fits -> print the brief with "Nothing for <agent> now", name the agent that fits the first open row, stop.
3. **Claim it (FIRST action, before any file change, build or test):** in that row set Status `claimed` (a review:
   `reviewing`), Claimed by `<agent + model> <yyyy-MM-dd HH:mm>`, and for new work Branch `<agent>/<id>` (e.g.
   `codex/U2`). Change nothing else, save (UTF-8 without BOM), re-read the row: if another agent's name is there, you
   lost the race: go back to step 2.
4. **Worktree** (skip for rows whose Touches say `home`):
   - New work: `& 'C:\Program Files\Git\cmd\git.exe' -C D:\Projects\Stranote worktree add D:\Projects\Stranote-wt\<id> -b <branch> main`
   - Review: `... worktree add --detach D:\Projects\Stranote-wt\<id>-review <branch>` (the author's worktree keeps the branch)
   Do ALL file work there. Files not committed on `main` are not in your worktree: read them from
   `D:\Projects\Stranote\...` by absolute path. Test server: first free port from 8767 (8765 is live, never use it).
   Tests use temp data only.
5. Print the brief, then start immediately (no "should I start?"):

---
## Stranote - Session Brief
**My task:** [id - title - branch - worktree path]   (or "Nothing for <agent> now - run <agent> next")
**Why this one:** [named by user / review of another agent's work / first open row that fits me]
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
change against `AGENTS.md`, the constitution and the task's text (UI changes: light, dark, 390px). Result:
- good -> row `approved` with a one-line verdict (note small issues; do not change the author's branch);
- problems -> row `open` again with the findings in the Task text ("fix: ..."); the next agent continues on the same
  branch and worktree.
Then `git worktree remove D:\Projects\Stranote-wt\<id>-review`.

## Mode B - UPDATE
Edit `D:\Projects\Stranote\STATE.md`, only what is yours (other agents may be editing their rows at the same time:
re-read the file right before you write, change only your row, the log and items you created):
- **Your row:** `review` (done, committed on your task branch, waiting for a review by another agent) with a
  one-line result; or `open` with a note if you stop unfinished (worktree and branch stay; the next agent continues
  there); or `blocked: <id>` if a new owner question stops it. Commit on your task branch before `review`
  (`git commit -F <file>`); never commit to `main` outside Mode C, never push.
- Rows done in the home folder with nothing to review (docs for the owner, board/rules upkeep) go straight to `done`.
- **Log:** add one line at the top `- <date> <agent>: <id> <result> (<branch>, tests n/n)`; keep the latest 8 lines.
- New work you found -> a new board row (next free id, Fit, Touches, Status `open` or `blocked: <why>`).
- **Tests** line: only if you ran the full suite (count + branch).
- Stable rules, run/test and the file map belong in `AGENTS.md`; change them there only when a decision changes.
- Keep the `## CURRENT STATE` heading text exactly (a hook reads it). Hard cap ~90 lines.

Output two lines: "Stranote state updated - <id> is <status>." and the **Agent fit** line of the next open task.

## Mode C - MERGE (only when the owner types `/stranote_resume merge`)
For each `approved` row, in table order, in the home folder `D:\Projects\Stranote` on `main`:
`git merge --no-ff --no-commit <branch>` -> run the full suite on the merged files -> green: `git commit -F <file>`,
row `done` with the merge commit, then `git worktree remove D:\Projects\Stranote-wt\<id>` and `git branch -d <branch>`.
A conflict or a red suite: `git merge --abort` (never `reset --hard`: the home folder holds uncommitted board edits),
set the row `open` with "fix: merge conflict / failing tests: ..." and continue with the next row. Never push.
Report merged / sent back.
