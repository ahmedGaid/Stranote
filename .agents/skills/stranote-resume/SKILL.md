---
name: stranote-resume
description: Resume or save the Stranote project session, for any agent (Claude Code, Codex). Use when the user types /stranote_resume, $stranote-resume, "resume Stranote", or /stranote_resume update "<what changed>". RESUME reads D:\Projects\Stranote\STATE.md, prints a brief and starts the Next action; UPDATE rewrites STATE.md after work.
---

# Stranote session (shared by every agent)

Entry and exit point for **Stranote** at `D:\Projects\Stranote` (the person's live install is `D:\Work`). The living
state is `D:\Projects\Stranote\STATE.md` (block `## CURRENT STATE`). Rules are in `AGENTS.md` (your agent has
probably loaded it; if not, read it once).

- no argument -> **Mode A (RESUME)**
- `update "<what changed>"` -> **Mode B (UPDATE)**. Run after every meaningful action and ALWAYS before ending a turn
  that changed project files.

## Mode A - RESUME
1. Read ONLY `STATE.md` (skip it if it is already in your context, e.g. a session hook injected it). Do NOT explore
   the codebase unless the state names a file for the next task.
2. Hand-off check: run `git status --short` and `git branch --show-current`
   (git path: `& 'C:\Program Files\Git\cmd\git.exe' -C D:\Projects\Stranote ...`). If there are changed files that
   the state's **Last agent** line does not explain, another agent may be mid-task: list them and ask the user before
   touching those files.
3. Output exactly:

---
## Stranote - Session Brief
**Goal:** [one line]
**Status:** [one line, current phase]
**Working now:** [claim line from STATE.md, or free]
**Last agent:** [who, when, branch, uncommitted work]
**Last completed:** [1-3 bullets]
**Next action:** [single most important next step, specific]
**Agent fit:** [from STATE.md; if you are not the best fit, say so before starting]
**Open items / blockers:** [real ones only, with their fit tags]
---

4. **Claim the task** (see "Claim before any work" below), then start executing the Next action immediately (it is
   already agreed; don't ask "should I start?"). Ask only if it is truly ambiguous or needs a decision only the user
   can make. If the user's message asks for something else, claim and do that first and mention the waiting Next
   action. Talk in Egyptian Arabic or English as the user writes; keep technical terms in English.

## Claim before any work (every task, every agent)
Before you change any file, run any build/test, or start any task in this project (the Next action or anything the
user asks), record that the task is with you. This is the FIRST action of the task:
1. Read the `**Working now:**` line in `STATE.md`.
   - `free` -> go to step 2.
   - Held by another agent or another session (even one with your own agent name) -> do NOT start. Tell the user who
     holds it, which task, since when, and ask: wait, take over, or work in a separate worktree. Continue only after
     they answer; if they say take over, write the old claim into **Open items** as "taken over from ...".
   - Held by you in this same session for the same task -> continue.
2. Replace the line with:
   `**Working now:** <agent + model> - <task id or short title> - since <yyyy-MM-dd HH:mm> - branch <branch>`
   and save `STATE.md` (UTF-8 without BOM). Change nothing else in the file.
3. Only now start the task. A new task in the same session = update the claim line first.
Read-only requests (status, questions, explanations) need no claim.

## Mode B - UPDATE
Announce the edit, then rewrite the `## CURRENT STATE` block of `STATE.md` (keep the heading text exactly: a hook
reads it). Keep it COMPACT:
- **Last agent:** your agent name and model (e.g. "Codex (gpt-...)", "Claude Code (Opus 5.5)"), date, branch, and
  every uncommitted file with one word on why. Update the `<!-- Last updated -->` comment the same way.
- **Working now:** set back to `free` when the task is finished or you are stopping. Keep your claim only if you
  will continue the same task in this same session right away.
- **Tests:** the latest count you actually ran (or keep the old one and say it was not re-run).
- Reset **Last completed** to the current session only.
- **Next action** = the next goal: one specific task the next agent can start without questions (task ids, files,
  what done looks like). Never leave it empty or vague.
- **Agent fit:** right under Next action, which agent and model fits it (format and rules in `AGENTS.md`,
  "Agents on this project"). Give every open item a `[fit: ...]` tag.
- Remove finished items from **Open items**.
- Stable rules, run/test and the file map belong in `AGENTS.md`; change them there only when a decision changes.
- Hard cap ~80 lines. History lives in `specs/*/tasks.md` (checked tasks + notes) and git, not here.

Output two lines: "Stranote state updated - /stranote_resume will load [summary]." and the **Agent fit** line of
the Next action.
