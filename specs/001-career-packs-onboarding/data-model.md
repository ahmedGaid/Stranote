# Data Model: Career packs and first-day onboarding

## CareerPack (`packs/<id>.json`)
| Field | Type | Rules |
|---|---|---|
| schemaVersion | int | = 1 |
| id | string | kebab-case, unique, = file name |
| name, field | string | required; field e.g. "IT / ERP", "Healthcare" |
| version | string | semver; bump on change |
| levels | string[] | e.g. Student, Junior, Mid, Senior, Lead |
| categories | {id, label, labelAr, color}[] | 1-6; replaces fixed Technical/Financial/Business/SCM |
| areas | Area[] | 1-40 |
| taskTypes | TaskType[] | 1-20 |
| phases | {name, percent}[] | optional; engine default otherwise |
| folders | {ticket[], work[], notesSections[]} | path templates with `{id} {module} {title} {prefix}` |
| saveTargets | SaveTarget[] | same shape as today |
| extractors | Extractor[] | see research R3 |
| starterLessons | Lesson[] | same schema as `Set-SnLesson` (teach-before-quiz rules apply) |
| skillMap | {skill, area, group, levels{junior,mid,senior}}[] | drives Skills and CV hints |
| vocabulary | {abbreviations{}, stopWords[]} | |
| onboardingQuestions | Question[] | role-specific wizard questions (prefix, versions, ticket format...) |
| settings | object | pack defaults merged over engine defaults |

**Area**: `{ id, name, category, concepts: [{id, title}] }`, `id` unique in pack (EBS: GL, AP, PLSQL, OAF...).
**TaskType**: `{ name, questions[], openQuestions[], checklist[], objects[] }` (today's shape, moved verbatim).
**Question** (onboarding): `{ id, label, help, type: text|select|multi|bool|time|days, options[], default,
writesTo }` where `writesTo` is a settings path (e.g. `prefix`, `career.weekend`).

## Profile (`<root>\04_Knowledge\Stranote\profile.json`)
| Field | Type | Notes |
|---|---|---|
| schemaVersion | int | 1 |
| language | {explain: "ar-EG" \| "en" \| ..., keepTermsInEnglish: bool} | |
| learningStyle | string[] | examples, analogies, short |
| roles | Role[] | ≥1 |
| ratings | {roleId: {areaId: new\|basic\|comfortable\|expert}} | |
| goals | {focusAreas[], target, dailyMinutes, reviewTime} | |
| privacy | {localOnly[], neverOnCv[]} | |
| onboarding | {state: required\|in-progress\|done, step, completedAt} | |

**Role**: `{ id, packId, level, years, companies[] }` - companies refer to `settings.career.companies[].name`.

## OnboardingAnswers (`onboarding.json`)
Raw answers per step `{ step, answers{questionId: value}, updatedAt }`; kept after completion for re-runs and pack
requests. Pasted CV text is stored only here, never copied into `cv.json`.

## Overrides (`overrides.json`)
JSON merge patch over (engine defaults + pack settings). Written by Save Settings; never touched by pack updates.

## FirstWeekPlan (`plan.json`)
`{ createdAt, items: [{ day: yyyy-MM-dd, lessonId, areaId, minutes, status: todo|done|skipped }] }`

## PackRequest (`pack-requests/<slug>.json`)
`{ slug, career, field, level, freeAreas[], freeTasks[], tools[], roleId, status: pending|drafted|accepted|rejected, draftPath, createdAt, updatedAt }`
(+ `packId`, `previousPackId` once accepted)

## State transitions
- Profile.onboarding: `required` -> `in-progress` (first step saved) -> `done` (Complete-SnOnboarding); re-run:
  `done` -> `in-progress` -> `done` (data kept).
- PackRequest.status: `pending` -> `drafted` (skill wrote a valid draft) -> `accepted` | `rejected`.
- Concept status from rating: new -> (lesson) taught -> (check passed) understood; expert -> known directly.

## Card/question compatibility
Cards and questions gain optional `roleId` and `areaId`; missing values are read as the profile's first role and the
card's `module`, so existing data needs no rewrite.
