# Research: task-type layouts, Data request type and file versions

## R1 - Where the layout lives
**Decision**: optional fields on `taskTypes[]` (`folders`, `saveTargets`, `attachmentsPath`, `useBaseChecklist`,
`useCommonQuestions`), resolved by one function `Get-SnTypeLayout` that falls back to `settings.ticketFolders`,
`settings.saveTargets`, `settings.attachmentsPath` and `true` field by field.
**Why**: the type is already the unit the person picks; spec 004 already puts questions, variants and checklists there;
one resolver keeps `New-SnTask`, the save panel and the attachments place consistent.
**Rejected**: a separate `layouts[]` list referenced by name (one more thing to keep in sync in Settings); layout per
variant (not needed for the owner's case; a variant can get it later with the same fields).

## R2 - Save-target indexes
Today the page sends `target` = index into `settings.saveTargets`. With per-type places that index would point to a
different list. **Decision**: `Get-SnTaskTargets($task)` returns the resolved list (type `saveTargets`, then general
targets whose path does not start with `{ticket}`; without type targets: the general list unchanged). `Resolve-SnTarget`,
`Get-SnTargetFolders`, `Save-SnFile` and `Get-SnMeta` use it; the page reads the list per task from meta / the task
payload. For every type without `saveTargets` the list and indexes are identical to today (test).
**Rejected**: sending the target path instead of an index (the server would have to trust a path from the page).

## R3 - Version naming
**Decision**: family = stem without a trailing `_v<n>`; plain stem = v1; next = max + 1, in the same folder. Versioned
places give the first file `_v1`. Records add `family`, `version`, `follows`, `note`.
**Why**: matches the `_v2` names `Save-SnFile` already writes on a clash, so old files read as families with no
migration; the version shows in Explorer and in the emailed file name; no rename, so nothing can be lost.
**Rejected**: latest = plain name + older moved to `_versions\` (renames on every save: two writes, a crash can leave
two "latest" files, links in `_NOTES.md` go stale) - kept as owner option Q1-B; a JSON index of versions (a second
truth that drifts from the folder).

## R4 - Asking "new or version"
**Decision**: the page calls `GET /api/families` for the chosen place (and sub-folder) before saving. Empty -> save as
new (no question). Not empty -> dialog: New file (name box) / New version of (families, latest first, guess
pre-selected) + note; "apply to all" for multi-file drops. The save call carries `versionOf` or `asNew`. Guess: same
extension first, then the family whose name shares the longest common prefix with the new name; in a versioned place
with exactly one family of the same extension, pre-select "new version".
**Why**: the question must come before the write (FR-006); a read-only list keeps the write path unchanged.
**Server re-check**: `-AsNew` with an existing name is refused (409-style message) so a stale page cannot overwrite;
`-VersionOf` recomputes the next number at write time.

## R5 - Settings type editor
The spec 004 editor already copies unknown type/question fields through. **Decision**: add a Layout part per type
(folders list editor with preview, places list with versioned switch, attachments folder, two switches); empty folders
list = "use the general folders" (field removed, not saved as `[]`, so the fallback stays). Pester round-trip test.

## R6 - Live install
Same as spec 004 R5: if the live `overrides.json` holds its own `types`, the new Data request type from the pack does
not show. The live-upgrade row checks this, shows the owner, and only on their word appends the pack's Data request
type to `overrides.json` (backup first). No other live data changes.

## R8 - Per-type phases (owner choice Q3-B, 2026-10-26)
**Decision**: optional `taskTypes[].phases` with a `column` per phase that names a general phase; the board keeps the
general columns and places cards by `column`, showing the task's own phase name. `Done` and `On Hold` must keep those
exact names because the engine and page treat them specially (close sets `Done`; ring colours, overdue, counts).
**Why**: one board stays readable when Report and Data request tasks are mixed; the task record needs no new field
(`phase` simply holds the type phase name), so history and `_NOTES.md` work unchanged.
**Rejected**: a separate board per type (many boards, filters break); mapping by percent only (two phases with the
same column would not be told apart). Code points: `Get-PhaseNames`/`Get-PhasePct` callers (`New-SnTask` first
phase, `Update-SnTask` choices/percent), `Get-SnMeta`, page `PHASES` uses (board columns, list groups, update select).

## R7 - Overlap with Phase A (board P4) and spec 004
`New-SnTask` and `Save-SnFile` are touched by spec 004 and by Phase A. **Decision**: build TL1 on main after AT0-AT5 are
merged, with small separate changes; P4 takes them in when forward-ported (same as spec 004 Q3).
