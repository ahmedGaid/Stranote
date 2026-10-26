# Quickstart: check spec 005 by hand (temp data only)

1. Start a dev server on a free port from 8767 with a temp config and a temp copy of `tests/fixtures/ebs-legacy`
   (`STRANOTE_NO_SCHEDULE=1`); never port 8765, never `D:\Work`.
2. New task -> type **Data request**: leave Filters blank, paste a SQL text and a screenshot into the attachments area,
   Create. Check the folder: only `01_From_Requester`, `02_Scripts`, `03_Data`; both pasted items in
   `01_From_Requester`; checklist = 6 data items; "Which filters / date range...?" is an open question.
3. Task page -> Save a file -> Query script: first save -> `<name>_v1.sql`, no question. Save again -> dialog asks New /
   New version (family pre-selected) -> note "added period filter" -> `<name>_v2.sql`; v1 unchanged; `_NOTES.md` logs
   the note.
4. Save -> Data sheet: drop `Book1.xlsx` as a new version of an existing sheet -> saved with the family name, next
   number.
5. New file with an existing name -> the app offers version or rename; nothing overwritten.
6. Create a Report and an Interface task -> folders, checklist and open questions as before (compare with main).
7. Settings > Task types -> Support -> Layout: folders `01_Evidence`, `02_Fix`, general checklist off -> Save 5 times ->
   reload: fields kept; new Support task uses them; an old Support task unchanged.
8. Light, dark and 390 px for the version dialog, the attachments area and the Layout part.
9. `Invoke-Pester <worktree>\tests` -> all green.
