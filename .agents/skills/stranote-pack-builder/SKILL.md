---
name: stranote-pack-builder
description: Draft a Stranote career pack for a career that has no pack yet, from the person's own "My career is not listed" request. Use when the user says "build my Stranote pack", "draft my career pack", "make a pack for <career>", "my career is not listed", or when Stranote shows a pack request waiting for a draft (Settings > Roles).
---

# Stranote pack builder

A person told Stranote their career is not listed. Stranote saved a **pack request** (job title, field, work areas,
typical tasks, tools) and keeps them on the General pack meanwhile. Your job: turn that request into a valid
**draft pack**, hand it in, and let the person accept it in **Settings > Roles**. You never switch their role yourself.

Rules that win over everything below:
- **Packs are data, not code** (constitution I). JSON only. Never edit Stranote source files to fit a career.
- **Never invent domain facts.** Build from the person's own words. Anything you add from general knowledge goes into
  `"x-unconfirmed"` so the person reviews it (they are the practitioner). If you are not sure, leave it out or ask.
- **No real people, clients, patients, companies or secrets** in the pack (placeholders and samples are fictional).
- Talk to the user in their language (Egyptian Arabic or English as they write); keep technical terms in English.
- Before running PowerShell here, load the `powershell51-gotchas` skill.

Full field reference: `D:\Projects\Stranote\docs\pack-authoring.md` (read sections 3-5 before your first draft) and
`specs/001-career-packs-onboarding/contracts/pack-schema.md`. Easiest examples: `packs\general.json`, `packs\nurse.json`.

## 1. Load the module and read the request
Execution policy is Restricted on this PC: run these in `powershell -NoProfile -ExecutionPolicy Bypass -Command "..."`
(or a script started with `-ExecutionPolicy Bypass`), all steps in the same process.

```powershell
Import-Module 'D:\Work\05_Tools\Stranote\Stranote.psm1' -Force -DisableNameChecking   # live install
Get-SnPackRequest | Select-Object slug, career, status, updatedAt                    # newest first
$req = Get-SnPackRequest -Slug '<slug>'; $req | ConvertTo-Json -Depth 5
(Get-SnLearnDir)                                                                         # the learn dir, e.g. D:\Work\04_Knowledge\Stranote
```

Only work on requests with status `pending` (or `drafted` if the person asks for changes). If there are several, ask
which one.

## 2. Ask a few short questions (only what the request does not answer)

Ask in one message, max 5 questions, with suggested answers they can confirm:
1. The stages a piece of work goes through, start to finish (becomes `settings.phases`; keep `Done` = 100).
2. For 2-3 of their typical tasks: what must be true before it is finished (becomes each task type's `checklist`).
3. What they write or save while working: notes, reports, drawings, spreadsheets (becomes `ticketFolders`,
   `saveTargets` and which file types the extractor reads).
4. Words, tools, standards or terms that come up all the time (becomes the `term` extractor list).
5. What must never appear on a CV or in a pack (client names, ids...), and what warning should the CV show if it
   detects one (becomes `ui.privateNames` and `ui.privateNamesWarning`).

If they say "you choose", use the General pack's values for that part and say so in `x-unconfirmed`.

## 3. Write the draft

Start from `packs\general.json` (copy it, never change the shipped file) and replace:

| Field | From |
|---|---|
| `id` | the request `slug` (file name must equal it) |
| `name`, `field`, `description` | request `career`, `field`; one plain sentence |
| `categories` | 2-4 groups that fit the work (e.g. Core work / Tools / Communication) with `label`, `labelAr`, `color` |
| `areas` | one per request `freeAreas` item (`taskModule: true`, a short upper-case `id`, a `category`) + `Other`. `concepts` only from what they said; else `[]` |
| `taskTypes` | one per `freeTasks` item + `Other`. Each: at least one intake question (`k`,`q`,`d`), `openQuestions`, `checklist` (from step 2), `objects: []` |
| `settings` | `phases`, `baseChecklist`, `commonQuestions`, `ticketFolders`, `saveTargets`, `notesSections`, `abbreviations` from step 2-3. Keep `workFolders` as in general. Never set `modules`, `types`, `knowledge` |
| `extractors` | one `term` extractor: `(?i)\\b(?<key>tool1|term2|...)\\b` from request `tools` + step 4 words, `files` from step 3, `group` = a category id, `minCount` 1, `maxCards` 6 |
| `ui` | `workspace`, `area`/`areas`, `cvTitle`, `sample` (fictional), `placeholders.taskTitle`, `privateNames` (JavaScript regex), `privateNamesWarning` (CV warning text when the pack prefix or `privateNames` matches), `skills.bullet` |
| `skillMap` | one `{ skill, area, group }` per area |
| `starterLessons` | `[]` (reserved) |
| `x-unconfirmed` | list of strings: everything you added that the person did not say |

Write it with UTF-8 without BOM (Arabic `labelAr` must survive):

```powershell
$dir = Join-Path (Get-SnLearnDir) 'packs'; New-Item -ItemType Directory -Force $dir | Out-Null
$path = Join-Path $dir "$($req.slug).json"
[IO.File]::WriteAllText($path, ($pack | ConvertTo-Json -Depth 20), (New-Object Text.UTF8Encoding $false))
```

## 4. Validate and hand it in

```powershell
Test-SnPack -Path $path                      # { ok, errors[] }: fix every error (each names its JSON path), repeat
Submit-SnPackDraft -Slug $req.slug           # validates again, sets the request to 'drafted' with its draftPath
```

`Submit-SnPackDraft` refuses an invalid file and leaves the request unchanged. Regex too slow? Use plain word
alternation (see pack-authoring.md, "The speed rule").

## 5. Tell the person

Short summary: pack name, areas, task types, phases, and the `x-unconfirmed` list to check. Then:
"Open Settings > Roles, check the draft and click **Accept and switch role**. Your tasks, cards and progress are kept."
Only if they explicitly ask you to accept it for them: `Approve-SnPackDraft -Slug <slug>` (returns `{ ok, errors[] }`).
To drop it: they click Reject, or `Deny-SnPackDraft -Slug <slug>` on request.

Changes later: edit the same file, run `Test-SnPack` and `Submit-SnPackDraft` again (before acceptance). After
acceptance the pack is live: bump `version`, keep ids stable (card ids depend on them), validate before saving.
