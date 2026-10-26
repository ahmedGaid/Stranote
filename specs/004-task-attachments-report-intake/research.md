# Research: task attachments and report intake

## R1 - Reuse `Save-SnFile` for attachments
**Decision**: add an `-Attachment` switch (and `-Question`) to `Save-SnFile`; it resolves the folder from
`settings.attachmentsPath` instead of a save-target index, then uses the same safe-name, `_vN` and record code.
**Why**: one writer for task files keeps one place for the Phase A lock (P4 task T016) and the existing 50 MB / name rules.
**Rejected**: a second writer `Save-SnAttachment` (duplicates the free-name and record logic Phase A must lock);
a fake save target in every pack (lost when `overrides.json` holds its own `saveTargets`).

## R2 - Upload order in the New task dialog
**Decision**: create the task first (`/api/new`), then send each file to `/api/savefile` with `attachment: true`, one
request per file, as the save panel does today. Show progress; collect failures; never retry automatically.
**Why**: the task folder must exist first; per-file requests keep one failure from losing the others (FR-010) and
avoid one huge JSON body.
**Rejected**: files inside the `/api/new` body (one failure would fail the task; very large body in PS 5.1).

## R3 - Large bodies in Windows PowerShell 5.1
The server reads the whole body and runs `ConvertFrom-Json`. A 50 MB file is ~67 MB of base64. **Check in AT1**: one
test that saves a 20 MB file through `/api/savefile` on a temp root (manual, not in the suite) and record the time in
the tasks file. If `ConvertFrom-Json` fails on large strings, parse the base64 field out of the raw body before
`ConvertFrom-Json` (no new dependency). Today's save panel has the same limit, so this is not a new risk.

## R4 - Conditions and variants in the engine
**Decision**: one helper `Resolve-SnIntake($typeDef, $answers)` returns visible questions, the matched variant and the
open questions from `askIfBlank`. `New-SnTask` (dashboard and terminal) and the page use the same rules; the page
mirrors the helper in JavaScript and the server re-checks (`required`, `options`) so a stale page cannot store hidden
answers. Depth limit 2 (choice -> question) keeps it readable.

## R5 - Live install and customised task types
`Save-SnOverrides` stores only what differs from defaults + pack, but an array that differs is stored whole. If the
live `overrides.json` already has `types` (the owner once edited task types), the new Report questions from the pack
stay hidden after the live upgrade. **Decision**: the live upgrade row checks `overrides.json` for `types`; if present,
it offers the owner a merge (add only the Report `questions` + `variants` from the pack, keep everything else) with a
backup first. No automatic change to live data.
Also fix the Settings type editor, which today rebuilds each question as `{k, q, d}` and each type as five lists
(`dashboard_template.html` ~line 2790): it must copy unknown fields through (FR-012), or the first Settings save would
store a stripped copy of `types` in `overrides.json`.

## R6 - Pasted screenshots
`paste` event on the dialog / Attach area: `clipboardData.items` of kind `file` with an `image/*` type become files named
`screenshot_<yyyyMMdd_HHmmss>.<ext>` (the page already does this for knowledge-card screenshots, `uploadShot`).

## R7 - Image previews (P3)
New GET `/api/file?path=<relative>`: only image extensions, `Assert-UnderRoot`, only under `01_Tickets` / `99_Archive`,
`Cache-Control: no-store`. Same pattern as today's `/img/*` route.

## R8 - Overlap with Phase A (board P4)
Phase A converts `New-SnTask` (T014) and `Save-SnFile` (T016) to locked writes. AT1 changes only the intake block of
`New-SnTask` (before any write) and the folder resolution of `Save-SnFile`. Whoever does P4 rebases onto these small
changes. The owner can instead choose to wait for P4 (Q3 in the hand-over).
