# Quickstart: check task attachments and report intake

Temp data only (copy of `tests/fixtures/ebs-legacy`), dev server on the first free port from 8767, never 8765 or `D:\Work`.

1. New task, type **Interface**: dialog and created task are the same as before; add 2 files -> both in
   `<task>\01_Requirements\Attachments`, listed on the task page.
2. New task, type **Report**: only the New/Fix choice shows; Create is refused until one is chosen.
3. Choose **New report**: today's questions; created task has today's checklist and open questions.
4. Choose **Fix an existing report**: fix questions show; report type is a list; "what is wrong" and "correction
   needed" are multi-line; drop 1 file on Problem, paste 1 screenshot on Expected, add 1 general file.
5. Leave parameters and request ID blank, Create -> task has the fix checklist, two open questions for the gaps, files
   in `Attachments\Problem`, `Attachments\Expected` and `Attachments`, each logged in `_NOTES.md`.
6. Switch Fix -> New before Create: no fix answer is stored.
7. Add a 60 MB file: refused before Create. Make one file fail (read-only target folder): task exists, the message names
   the file.
8. Task page -> **Attach** -> paste a screenshot: saved and listed without a reload; an image shows a preview (AT4).
9. Settings -> Task types -> Report -> Save 3 times: choices, conditions and file questions are still there.
10. Terminal: `New-SnTask` Report -> Fix asks the same questions; `-Attach` copies files, originals untouched.
11. Light, dark and 390 px: dialog scrolls, Create button always visible, no console errors.
