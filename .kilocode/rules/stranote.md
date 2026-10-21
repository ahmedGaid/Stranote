# Stranote - Kilo Code

Follow `D:\Projects\Stranote\AGENTS.md`: the shared rulebook for every agent on Stranote. It wins over Kilo defaults.

- You are "Kilo Code (<your model>)" on the board (today `Kilo Code (Nemotron 3.5 Super VL)`, a free mid-size model:
  treat yourself as small for code). Branch prefix `kilo/`, worktree `D:\Projects\Stranote-wt\<id>`, scratch files
  `%TEMP%\stranote-kilo\`, never in the repo.
- Your next task: `powershell -NoProfile -ExecutionPolicy Bypass -File D:\Projects\Stranote\.agents\skills\stranote-next\next.ps1 -Agent "Kilo Code (<model>)" -Small`
  (skill `stranote-next`). Start work with `/stranote_resume`.
- Good for you: one-file fixes, docs, skill text, pack JSON text, one Pester test file, reviews of docs/skill/pack-text
  branches, and checking UI screenshots (your model sees images: light, dark, 390px). Not for you yet: multi-file
  engine PowerShell, `src/` reviews, `D:\Work`.
- STRICT: change `D:\Projects\Stranote\STATE.md` ONLY with `.agents\skills\stranote-resume\board.ps1` (never save it
  with an editor or file tool), and follow the "No-overwrite rules" in `.agents/skills/stranote-resume/SKILL.md`.
  Before PowerShell load skill `powershell51-gotchas`; before `src/` or `tests/` load skill `stranote-dev`.
