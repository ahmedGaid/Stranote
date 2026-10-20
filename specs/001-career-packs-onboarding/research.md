# Research: Career packs and first-day onboarding

## R1. Pack file format
- **Decision**: One JSON file per pack with `schemaVersion: 1`, validated by `Test-SnPack` in PowerShell.
- **Rationale**: Windows PowerShell 5.1 parses JSON natively; YAML would need a module. Same format as all Ops data.
- **Alternatives**: YAML (friendlier to write, no parser); PowerShell data files `.psd1` (no comments in JSON, but
  psd1 is not usable from the browser); a folder per pack (useful later for images; v1 keeps one file).

## R2. What moves from code to the EBS pack
- **Decision**: Move from `settings.default.json` and code into `oracle-ebs-technical.json`: modules -> `areas`,
  `knowledge.financialModules` / `scmModules` -> area `category`, task `types` (questions, openQuestions,
  checklist, objects), `ticketFolders`, `notesSections`, `workFolders`, `saveTargets`, `abbreviations`,
  `stopWords`, the API/table regexes in `Get-TaskCodeFacts` / `Get-SnSuggestions` (package prefixes, member
  blacklist) -> `extractors`, CV skill groups -> `skillMap`, the `XXCUST` prefix question -> `onboardingQuestions`.
- **Stays in engine**: phases and priorities defaults (career-neutral), Leitner, review, lessons, visual faces,
  categories list (Technical / Financial / Business / SCM become pack-defined `categories`).
- **Rationale**: Constitution I; T030 greps the engine for EBS words to prove it.

## R3. Extractors
- **Decision**: An extractor is `{ id, kind, pattern, group, exclude[], minCount, maxCards, cardTemplate }` where
  `kind` is one of `api | table | term | decision | answer`, `pattern` is a .NET regex with named groups, and
  `cardTemplate` builds topic/fact. The EBS extractors reproduce today's logic exactly; card IDs stay
  `A-<md5(taskId|kind|key)>` so progress is kept.
- **Rationale**: Covers code (APIs, tables), prose terms (IFRS 15, drug names) and structured notes (Decisions).
- **Alternatives**: Keyword lists only (cannot catch `PKG.PROC` shapes); AI extraction (no live AI, privacy).
- **Guard**: patterns are compiled with a 200 ms match timeout at validation; invalid or slow patterns fail
  validation (spec edge case).

## R4. Settings = defaults + pack + overrides
- **Decision**: Effective settings = `settings.default.json` (engine) <- pack `settings` <- `overrides.json` (user).
  Saving in Settings writes only the diff to overrides.
- **Rationale**: FR-012, pack updates must not erase user changes.
- **Migration**: today's `settings.json` minus defaults minus EBS pack = the user's overrides (computed once).

## R5. Self-rating -> concept status
- **Decision**: Each pack area has `concepts[]` (ids + titles). Rating mapping: expert -> `known`; comfortable ->
  `understood`; basic -> `taught` (short lessons, quick check); new -> `new` (full lesson first). Statuses are
  written with `Set-SnConceptStatus -Source onboarding`, which never downgrades `understood`/`known`.
- **Rationale**: Constitution II; reuses the existing gate (`Test-SnQuestionReady`).

## R6. First-week plan
- **Decision**: Order starter lessons by (goal areas first) then (rating new before basic) then pack order; fit them
  into the daily minutes (10-minute lesson = 1 slot); spread over the working days of the first week; store in
  `plan.json` and show on Daily review as "Today's new lesson".
- **Alternatives**: Let the user pick lessons (slower day one; still possible from Knowledge).

## R7. Unlisted careers
- **Decision**: Wizard saves `pack-requests/<slug>.json` (answers + free-text areas and tasks). The `ops-pack-builder`
  Claude skill (T042) drafts `<learn dir>/packs/<slug>.json`, runs `Test-SnPack`, and the
  user accepts it in Settings > Roles. Until then the General pack is used.
- **Rationale**: No API keys in the app (Constitution III); the person's own Claude session does the drafting.

## R8. Wizard placement
- **Decision**: Full-screen step wizard inside `dashboard_template.html`, shown when `GET /api/profile` returns
  `{ onboarding: "required" | "in-progress" }`; each step saves to `onboarding.json` (resume, FR-004).
- **Rationale**: One HTML app today; no second page to maintain.

## R9. Renames without breaking the install
- **Decision**: New names `Stranote.psm1`, `StranoteServer.ps1`; old files remain as one-line wrappers that dot-source the
  new ones; functions keep their `Ebs*` names in v1 and gain `Ops*` aliases.
- **Rationale**: Constitution IV: shortcuts, `ebs.cmd`, scheduled task and Claude skills keep working.
