---
name: stranote-learn
description: Build the user's learning and CV material inside Stranote (D:\Work), for the active career pack (Oracle EBS for this user). Use when the user says "make a quiz for <task>", "quiz me on GL", "test me", "add questions", "what did I learn from <task>", "make knowledge cards", "save this as a card", "write CV bullets", "update my CV", "what skills can I add to my CV", or after finishing tracked work when knowledge is worth keeping.
---

# Stranote Learn - knowledge cards, quizzes, CV

Everything goes through the Stranote PowerShell module (never edit the JSON files by hand):

```powershell
Import-Module 'D:\Work\05_Tools\Stranote\Stranote.psm1' -Force -DisableNameChecking
```
Data lives in `D:\Work\04_Knowledge\Stranote\` (cards.json, questions.json, cv.json). The dashboard (Knowledge, Quiz, Skills, CV views) shows it after a page refresh.

## 0. Read the active career pack (first, every time)

Stranote works for any career; the field, areas, card categories and CV privacy rules come from the person's
**active career pack**:

```powershell
$pack = Get-SnPackOrLegacy   # active pack (old installs: the EBS pack); $null = not onboarded yet
"$($pack.id) | $($pack.name) | $($pack.field)"
$pack.categories | Select-Object id, label        # the only valid card categories
$pack.areas | Select-Object id, name, category    # areas (EBS calls them modules)
$pack.ui.privateNames                             # regex of names that must never reach the CV (may be empty)
```
Examples in this skill are from the EBS pack (`oracle-ebs-*`). For another pack keep the method and replace the
domain: its areas, its categories, real names from that field. Never invent domain facts; if unsure, ask the user.

## 1. Read the source material first

```powershell
Show-SnTask -Id T-0001 6>&1 | Out-String          # details, answered questions, checklist, history
Get-SnTaskFiles -Id T-0001 | ConvertTo-Json -Depth 4  # scripts saved for the task (read the relevant ones)
Get-SnSuggestions -Id T-0001 | ConvertTo-Json      # APIs and tables found in its scripts
(Get-SnLearn).cards | Where-Object taskId -eq 'T-0001'   # existing cards (don't duplicate)
```
For "quiz me on GL" use all cards/questions/tasks of that area (module). Only ask about things that are true in the
pack's field (EBS pack: Oracle EBS R12); if unsure, leave it out.

## Automatic knowledge (already there)

Stranote builds cards automatically on every change (`Sync-SnKnowledge`, run by `Update-SnDashboard` and on every dashboard load):
task summary, answered business questions, bullets under "## Decisions" in the task's `_NOTES.md`, and whatever the
pack's `extractors` find in the task's files (EBS pack: APIs called in its scripts, with the code snippet, 3+ procedures
of one package become one card; tables used, with select/insert/update/delete counts).
Each gets a flashcard; each API card also a "which package provides ...?" question. These have `source = 'auto'`.
The user Keeps (`Set-SnCardKeep`) or Hides (`Remove-SnCard` on an auto card = hidden for good) them.
So: don't duplicate what auto already covers. Your job is the *understanding* the scanner can't see: why, gotchas, order of calls,
setup steps, and good multi-choice/write-the-query questions. Tip for the user: writing decisions as bullets under
"## Decisions" in `_NOTES.md` turns them into cards automatically.

## Arabic explanations (always)

The user wants every card and quiz answer explained in **simple Egyptian Arabic, short (3-5 lines) + one example**,
keeping every technical keyword of the field in English exactly as it is (EBS: API, table and column names,
responsibility, value set, concurrent program, staging, rollback). Stored in `explain-ar.json`, keyed by card or
question id, so the automatic re-scan never erases them. A question without its own entry shows its card's.

```powershell
Set-SnArabic -Map @{ 'A-32df971fb2' = @{ text = 'دي الـ procedure اللي بتعمل الـ security rule ...'; example = 'عايز محاسبين فرع القاهرة ...' } }
# or many at once from a UTF-8 JSON file {"<id>": {"text": "...", "example": "..."}}:
Set-SnArabic -Path 'C:\...\ar.json'
```
Each entry can also have `detail`: a longer explanation shown in Stranote' explanation window ("اشرحلي" button), in light
Markdown: `## heading`, `- list`, `1. list`, `> rule to remember`, `| table |`, fenced code blocks, `inline code`, `**bold**`.
Use it for "explain in more detail" requests: quote the user's own script lines (file + line number), end with a
"> **قاعدة تفتكرها:** ..." line. Fields you omit keep their value (`Set-SnArabic -Map @{ id = @{ detail = '...' } }`).
Write Arabic JSON with the Write tool (UTF-8), not inside a PowerShell string. When the user asks
"اشرح كروت T-0001 بالعربي" or after new automatic cards appear, fill in every card id with no entry
(`$ar = Get-SnArabic; (Get-SnLearn).cards | ? { -not $ar.($_.id) }`). For `Add-SnQuestions` add
`explainAr` (and optional `exampleAr`) to each question. Be accurate; if unsure about a domain detail, say less.

## Screenshots of work screens (EBS forms in the examples)

Each card's explanation can hold screenshots of the real screens of the person's work systems (EBS forms/pages here;
`$pack.ui.screenshotsTitle` names them for the pack). Never request screens that would show private data
(e.g. patient records in a nurse pack). They live in `images` of the card's explain-ar.json entry:
`title`, `nav` menu path, `file` in `D:\Work\04_Knowledge\Stranote\img\`. An item without `file` is a requested screen:
the user captures it (Win+Shift+S) and pastes it into the slot in Stranote' explanation window.
- You cannot log into EBS (never ask for or type passwords) and Oracle Forms (Java) does not open in the built-in
  browser, so the user captures; you request the right screens:
  `Set-SnShotRequests -Id <cardId> -Shots @(@{ title = 'Define Security Rules form'; nav = 'General Ledger > Setup > Financials > Flexfields > Validation > Security > Define' })`
  Use standard menu paths and say they may differ in the user's menus.
- When the user says they added screenshots ("شوف الصور اللي حطيتها في T-0001"): read the image files with the Read
  tool, then add to that card's `detail` a section `## على الشاشة` that walks through the form in Egyptian Arabic:
  which field maps to which table/column, what to click, and the gotchas. Screenshots may contain company data:
  never copy them into CV material.

## Categories

Every card (and its questions) has one category, and it must be an `id` from `$pack.categories` (General pack:
Work / People / Growth / Tools; nurse: Clinical / Medication / ...). Pass `-Category` to `Set-SnCard`, or change one
with `Set-SnCardCategory -Id <cardId> -Category <id>`. When asked for knowledge from a task, cover every category
that is relevant, not only the most obvious one.

EBS pack categories: **Technical** (code, APIs, tables, AOL/FNDLOAD, setup mechanics),
**Financial** (finance/accounting concepts and Oracle Financials functionality: GL, AP, AR, FA, CE ...),
**Business** (business rules, requirements, decisions, process: why the business needs it),
**SCM** (supply chain: PO, INV, OM, WSH, BOM, WIP ...). Automatic rule there: business answers/decisions -> Business,
APIs/tables -> Technical, otherwise by module.

## Teach before quiz (lessons, built on the `adaptive-teacher` skill)

Stranote never quizzes the user on a concept before it is explained: a question is quiz-ready only if it was answered
before, or its card/question is `understood` (explained + check passed) or `known` (user says they know it).
Entry points in Stranote: "علّمني التاسك دي" on a task, "مش فاهم، علّمني" in the explanation window and on wrong
quiz answers, and the "N سؤال مستنيين شرح" box on the Quiz page. Without a written lesson Stranote builds one from the
cards' Arabic explanations; a lesson you write is better. Load the `adaptive-teacher` skill for the method
(CAMP: Context -> Anchor -> Map -> Practice, unique analogy per concept, Egyptian Arabic, technical terms in English),
adapted to the user's rules: **assume a beginner, teach first, then check understanding, then quiz**. Its
calibration happens in Stranote through the answers (two first-try passes make explanations shorter), so do not put a
quiz before the explanation. An optional unscored `prompt` ("قبل ما أشرح، تفتكر...؟") is fine.

Write the lesson as UTF-8 JSON (Write tool), then `Set-SnLesson -Path <file>` (it validates). Lesson id = task id
(e.g. `T-0001`) for a task lesson. Shape:
```json
{ "id": "T-0001", "title": "...", "taskId": "T-0001", "summary": "جملة الخلاصة بالمصري",
  "concepts": [ {
      "id": "c1", "title": "Flexfield security rules", "cardIds": ["K-1c0ed8fd"], "questionIds": ["Q-..."],
      "prompt": "(اختياري) سؤال تفكير قبل الشرح",
      "why": "ليه مهم - في سطر", "how": "بيشتغل إزاي - 2 لـ 3 سطور", "when": "امتى تستخدمه",
      "analogy": "تشبيه من الحياة، مختلف لكل مفهوم", "example": "مثال من شغل اليوزر الحقيقي",
      "steps": ["خطوة 1", "خطوة 2"], "code": "(اختياري) سطور من الـ scripts بتاعته",
      "simpler": [ { "analogy": "تشبيه أبسط تاني", "text": "شرح أبسط", "example": "مثال تاني" } ],
      "check": { "type": "mcq", "q": "scenario question in English", "options": ["..","..",".."], "answer": 1,
                 "explain": "short English", "explainAr": "تصحيح لطيف بالمصري" } } ],
  "practice": [ { "type": "tf|mcq|open", "q": "...", "options": [], "answer": "...", "explainAr": "..." } ] }
```
Rules: 4-6 small concepts per lesson, ordered from basics to the task's details; every concept has `how` and a
graded `check` (mcq/tf, testing application, not trivia) plus at least one `simpler` variant with a different
analogy; `practice` 3-5 items getting harder (end with an `open` apply-it question). List the card ids and question
ids the concept covers, so passing it unlocks exactly those quiz questions.

**"جاوب أسئلتي في Stranote"** (or the old "جاوب أسئلتي في Stranote", or when pending items exist): `Get-SnPendingFollowups`. For each:
- `question`: answer in Egyptian Arabic, short, with an example from the user's work, end by checking understanding
  ("كده وضحت؟") -> `Set-SnFollowupAnswer -Id <id> -Answer '<markdown>' -Example '<...>'` (write long text via a
  UTF-8 JSON file read in PowerShell, not inline Arabic).
- `simpler`: add one more `simpler` variant (new analogy + example) to the lesson concept, or to the card via
  `Set-SnArabic -Map @{ <cardId> = @{ detail = '...' } }`, then answer the follow-up with a one-line note.
- `lesson`: write the full lesson for that task with `Set-SnLesson`, then answer the follow-up.
Tell the user to refresh Stranote; the answers appear inside the lesson and under "أسئلتي".

## Exercises from `learning-opportunities`

When the user does a `learning-opportunities` exercise (offered after you build something for them), close it by
storing the result in Stranote:
- what they got right / the gap they found -> `Set-SnCard -TaskId <task> -Topic ... -Fact ... -Category <...>`
  plus Arabic via `Set-SnArabic` (text + example taken from the exercise itself);
- if they explained it back correctly -> `Set-SnConceptStatus -Keys <cardId> -Status understood -Source exercise`;
- if they struggled -> leave it `taught`, and add 1-2 questions with `Add-SnQuestions` (with `explainAr`) so the
  quiz brings it back after the lesson.
Language and order follow the user's rules in CLAUDE.md (Egyptian Arabic, teach before quiz, ungraded predictions).

## Daily review (short + long memory)

Stranote has a **Daily review** page (sidebar, key `R`, or `http://localhost:8765/#review`). The scheduled task
"Stranote Morning Review" (`05_Tools\Stranote\Start-SnMorning.ps1`) opens it at log on and at 09:00, once a day,
before 14:00, unless today's review is done. `-Install -Time 08:30` changes the time, `-Uninstall` removes it,
`-Force` opens it now. Log: `04_Knowledge\Stranote\morning.log`.
- `Get-SnDailyReview` picks ~10 quiz-ready questions: due ones (box 1-2 = `short`, box 3-5 = `long`) plus up to 3
  `surprise` questions: practised before, not due, not seen for 3+ days (weighted to older/stronger ones).
- `Submit-SnAnswer -Id .. -Grade again|hard|good|easy [-Surprise]`: again = box 1, back tomorrow (counts a lapse
  if it was box 3+); hard = same box; good = +1; easy = +2. A right surprise keeps its schedule.
- `Save-SnReviewDay` logs the day in `review-log.json`; the streak skips weekend days.
When the user asks "how is my memory / what did I forget", read `questions.json` (`lapses`, `hist`, `wrong`) and
teach the forgotten concepts again (simpler, new analogy) before adding new questions on them.
Questions you add only reach the review after the concept is taught, so put new questions behind a lesson or
mark the concept understood after you teach it.

## 2. Knowledge cards ("what did I learn")

One fact per card. Topic short and searchable; fact 1-3 sentences; optional code.
```powershell
Set-SnCard -TaskId 'T-0001' -Topic 'API: FND_FLEX_VALUE_RULES_PKG.INSERT_ROW' `
  -Fact 'Creates the security rule header. Lines go in FND_FLEX_VALUE_RULE_LINES, assignment to responsibilities in FND_FLEX_VALUE_RULE_USAGES.' `
  -Code "fnd_flex_value_rules_pkg.insert_row(...);" -Tags 'GL','FND_FLEX_VALUE_RULES_PKG','Security rules'
```
Tags: the area id (EBS: module code), the real tool/object names (EBS: API/package names; they become skills), and a topic word. Each card automatically becomes a flashcard. Propose cards to the user first (a short list), save the ones they accept.

## 3. Quiz questions

Write 10-15 per request, mixing types, ordered easy to hard. Every question needs a short `explain`.
```powershell
Add-SnQuestions -TaskId 'T-0001' -Questions @(
  @{ type='mcq';   q='Which table stores the security rule header?'; options=@('FND_FLEX_VALUE_RULES','FND_FLEX_VALUE_RULE_LINES','FND_FLEX_VALUES','FND_RESP_FUNCTIONS'); answer=0; explain='...'; tags=@('GL','Security rules') },
  @{ type='tf';    q='A security rule has no effect until it is assigned to a responsibility.'; answer=$true; explain='...' },
  @{ type='blank'; q='The value set of a segment is stored in FND_ID_FLEX_SEGMENTS.________.'; answer='FLEX_VALUE_SET_ID'; explain='...' },
  @{ type='open';  q='Write a query that lists all security rules of a value set by name.'; answer="select r.flex_value_rule_name from fnd_flex_value_rules r join fnd_flex_value_sets s on s.flex_value_set_id = r.flex_value_set_id where s.flex_value_set_name = :vs"; explain='...' }
)
```
Visual memory: each card has its own face (colour, glyph, icon) that is repeated on its questions. Give every question the `cardId` of the card it tests (`@{ ...; cardId='A-...' }`) so the question shows the same picture; questions linked through a lesson concept (`cardIds`/`questionIds`) get it too.
Rules: `mcq` answer = 0-based index, 3-4 plausible options, vary the position of the right one. `tf` answer = $true/$false. `blank` answer = exact expected text; alternatives separated by `|`. `open` = write-the-query / explain questions, self-graded against the model answer. Use real names from the field (EBS: real object names). Don't repeat existing questions (`(Get-SnLearn).questions`).

## 4. CV

- Skills on the CV and hints come from the dashboard's Skills/CV views (computed from tasks, cards and quiz results). To see what is ready: ask the user to open **CV**, or reason from finished tasks and cards.
- Write achievement bullets for finished tasks:
```powershell
Add-SnCvBullet -TaskId 'T-0001' -Text 'Built a PL/SQL upload using FND_FLEX_VALUE_RULES_PKG to create GL security rules from CSV, replacing manual setup for 40+ rules across 12 responsibilities.'
```
Bullet rules: action verb + what (real tool/object names of the field; EBS: object/API names) + business result with a
number; one line; no client/company names, ticket IDs, sensitive volumes, or anything matching the pack's private-name
pattern (the CV is for other employers). Check before saving:
`if ($pack.ui.privateNames -and $text -match $pack.ui.privateNames) { <rewrite the bullet> }`
(EBS: internal `XX` custom objects; nurse: MRN, bed/room numbers). If you don't know the number, ask the user for it
instead of inventing one.
- Export happens from the CV view (Word + Markdown into `D:\Work\06_Admin\CV`).

## Reply format

After saving, reply briefly: what was added (counts), where to see it (Knowledge / Quiz / CV view, refresh the page), and e.g. "5 questions are due today - press 5 in Stranote to start the quiz".
