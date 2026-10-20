---
name: ebs-dashboard-guide
description: After ANY Oracle EBS deliverable (PL/SQL, API script, SQL, report/BIP, interface, conversion, FNDLOAD/AOL setup, concurrent program, value set, personalization, OAF, workflow, alert, data fix, deploy/rollback script, analysis, design), append a "Record it on your dashboard" guide for the user's Stranote (D:\Work) - task to use or create, each file's destination, sub-folder and run order, and the progress update. Use it automatically, even unasked.
---

# Stranote Dashboard Guide

The user tracks all EBS work in a local dashboard (http://localhost:8765, started by the
**Stranote** Desktop shortcut / `D:\Work\stranote.cmd`). Every time you produce EBS work,
finish the work first, then append the guide below so nothing is lost.

Skip the guide only for pure questions that produce no deliverable (e.g. "what does this API do?").
For those, add one line: *"If this becomes a task, tell me and I'll prepare the dashboard entry."*

## 1. Read the live state (always - the user edits lists in Settings)

```powershell
Import-Module 'D:\Work\05_Tools\Stranote\Stranote.psm1' -Force -DisableNameChecking
Get-SnTask | Format-Table -AutoSize | Out-String -Width 200      # active tasks
Get-SnMeta | ConvertTo-Json -Depth 6                            # modules, types, priorities, phases, typeQuestions, saveTargets
```
If an existing task looks related, read it: `Show-SnTask -Id <ID>` (checklist numbers, open questions, current phase).
Never invent list values: module, type, priority, phase and destination names must come from `Get-SnMeta`.
If the module can't be loaded, still give the guide using the defaults in `references/dependency-map.md` and say so.

## 2. Decide: existing task or new task

- Match on module + subject words in the title/description. If one task clearly matches, use it.
- If two could match, name both and recommend one.
- If none match, prepare a **new task** with every field filled in.

## 3. Write the guide (use exactly this structure, keep it tight)

### Record it on your dashboard

**Task:** `T-0001 - Security Rule Upload Using API` (existing - click its card)
*or, for a new task:* click **+ New task** and enter:

| Field | Value |
|---|---|
| Ticket ID | the user's ticket number if known, else leave blank (auto ID) |
| Title / Module / Type / Priority / Due / Requester | ... |
| Description | one or two sentences |
| *Type details* | one row per intake question of that type (`typeQuestions`), with the answer you know or "leave blank" |
| Extra questions | anything still unknown that the business must confirm |

**Files to save** (card > **+ Save a file / script**). One row per file, **including every dependency**
(see `references/dependency-map.md`), in install/run order:

| # | File name | What is it? (destination) | Sub-folder | How |
|---|---|---|---|---|
| 1 | `XXCUST_GL_SEC_RULE_PKG.pks` | Production code (Git repo) | `db\packages` | Paste |
| 2 | `install_sec_rule.sql` | Deployment script | - | Paste (numbered automatically) |

Rules for this table:
- Use destination names exactly as in `saveTargets`. Mention **numbered** for destinations with `prefix=true` - the user types the plain name, the dashboard adds `<ID>_NN_`.
- Production objects (packages, tables, views, ldt, rdf, BIP templates, ctl, shell, wft) go to the **repo** with the right sub-folder; scratch/test calls go to **Task script**; install, rollback and data-fix scripts go to **Deployment script** in run order; screenshots/outputs go to **Test evidence**.
- Something reusable (a clean API call example)? Add a row for **Reusable snippet** too.
- If an object you wrote depends on setup that you did not write (concurrent program, value set, request group, lookup, profile, grants/synonyms), still list it as a row marked *"to create - extract with FNDLOAD"* so the user doesn't forget it. Give the FNDLOAD command in the code section of your answer, not in the table.

**Update progress** (same card > *Update progress* > **Save update**):
- Phase: `<phase from settings>` - percent fills in automatically (or give a number)
- Note: one line describing what was done (write it for them)
- Tick: the checklist items this work completes, by their exact text (and number from `Show-SnTask` if known)
- Answer: open questions this work answers, with the answer
- Add question / Blocker: only if this work revealed one

**Learn** (task page > *Learn* > + Add a card): suggest 2-3 knowledge cards from this work, as a short list of
`Topic - one-line fact` (real API/table names). If the work finishes a task, also draft one CV bullet
(verb + EBS object/API + result with a number placeholder). Details: the `stranote-learn` skill.

End with exactly one offer line:
*"Want me to record this for you? I'll create/update the task, save the files and add the cards."*

## 4. If the user says yes

Use the module directly (same rules as the `ebs-task` skill):
- New task: `New-SnTask -NonInteractive ...` with the values from your table.
- Files: `Save-SnFile -Id <ID> -Target <index in saveTargets> -SubFolder '<sub>' -FileName '<name>' -Text $content [-AddPrefix] [-AddHeader -Purpose '...']`
  (`-AddPrefix` when that destination has `prefix=true`; save in the run order of the table).
- Progress: `Update-SnTask -Id <ID> -Phase ... -Note '...' -Check <n,...> -Answers @{ '<n>' = '...' }`.
- Cards / CV bullet: `Set-SnCard ...` and `Add-SnCvBullet ...` as described in the `stranote-learn` skill.
- Then reply with the IDs/paths created, and remind them the dashboard card shows everything (refresh the page).

## Style

- The guide goes **after** the deliverable, under a horizontal rule, never instead of it.
- Tables, not prose. No more than ~25 lines unless the work really has many files.
- Use the user's real task IDs and the real custom prefix from `Get-SnMeta`.
