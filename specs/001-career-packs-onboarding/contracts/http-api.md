# Contract: HTTP API changes (localhost:8765)

All POST requests require header `X-EBS: 1` (unchanged). JSON in/out, UTF-8.

| Method | Path | Body / query | Response |
|---|---|---|---|
| GET | `/api/packs` | - | `[{ id, name, field, version, levels, areas:[{id,name,category}] }]` (summary of shipped + custom packs) |
| GET | `/api/packs/get?id=nurse` | - | full pack JSON |
| GET | `/api/profile` | - | `{ profile, onboarding: { state, step }, roles:[...] }`; `state` = `required` when no profile |
| POST | `/api/onboarding/save` | `{ step, answers }` | `{ ok, state: "in-progress", step }` (resume point) |
| POST | `/api/onboarding/complete` | `{}` (uses saved answers) | `{ ok, profile, createdFolders[], conceptsSet, plan:{items[]}, reviewTime }` |
| POST | `/api/onboarding/restart` | `{}` | `{ ok, state: "in-progress" }` (data kept) |
| POST | `/api/packs/request` | `{ career, field, level, freeAreas, freeTasks, tools }` (lists or one-per-line text) | `{ ok, slug, path, request }` |
| POST | `/api/packs/accept` | `{ requestId }` | `{ ok, packId }` or 400 `{ error, errors[] }` |
| POST | `/api/profile/role` | `{ packId, level, years, company }` | `{ ok, role }` |
| GET | `/api/plan` | - | first-week plan with statuses |

Changed:
- `GET /api/settings` returns `{ settings (effective), overrides, pack:{id,name,version}, ... }`.
- `POST /api/settings` stores only the diff in `overrides.json`.
- `GET /api/learn` cards/questions include `roleId`, `areaId` (derived when missing).

Errors: 400 `{ error: "message", errors: ["path: problem"] }`; 404 for unknown pack id.
