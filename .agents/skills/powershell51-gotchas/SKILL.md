---
name: powershell51-gotchas
description: Pitfalls of Windows PowerShell 5.1 on this PC that already caused bugs (JSON arrays, function returns, swallowed exceptions, encodings, long paths, string interpolation). Load BEFORE writing or debugging PowerShell scripts, modules or Pester tests here, especially code that reads/writes JSON or files with Arabic text.
---

# Windows PowerShell 5.1 gotchas (all hit for real)

**JSON and arrays**
- `ConvertTo-Json` writes an array that went through a function return as `{"value":[...],"Count":n}`.
  Fix once per module: `Remove-TypeData System.Array -ErrorAction SilentlyContinue`.
- Functions unroll arrays: a one-item list comes back as a single object. Return `,$x`.
- `$v = if (...) { $arr } else { ... }` also unrolls. Assign inside each branch instead.
- `ConvertFrom-Json` of a file holding an array passes through `Where-Object` as ONE object: add
  `| ForEach-Object { $_ }` before filtering.
- A JSON array can satisfy `-is [PSCustomObject]`: test `-is [Collections.IList]` (and string) first.
- Before `Add-Member -NotePropertyValue $val`, use `$val.psobject.BaseObject` for values from function returns.
- `@(@('a','b'))` collapses a single-pair list: build lists of pairs explicitly or edit one item at a time.
- Comma binds tighter than `+`: `@('x', 'a' + 'b')` concatenates arrays. Parenthesise each element.

**Errors and parsing**
- Exceptions thrown in property getters (e.g. `.Count` of a `MatchCollection` with a regex timeout) are silently
  swallowed and return `$null`. Use methods (`$m = $rx.Match(); while ($m.Success) { $m = $m.NextMatch() }`).
- .NET exceptions from method calls arrive wrapped in `MethodInvocationException`: a typed `catch [X]` misses them.
- `"$proc?"` parses `?` into the variable name: write `"$($proc)?"`.
- Variables are case-insensitive: `$live` and `$Live` are the same variable.
- No `&&`, `??`, ternary. Use `; if ($?) {}` and if/else.

**Files and encoding**
- Script files are read as ANSI unless they have a BOM: a `.ps1` with Arabic literals breaks. Keep scripts ASCII, or
  run them with `& ([scriptblock]::Create([IO.File]::ReadAllText($p, [Text.Encoding]::UTF8)))`.
- Write UTF-8 without BOM: `[IO.File]::WriteAllText($p, $text, (New-Object Text.UTF8Encoding $false))`.
- Paths over 260 chars (e.g. the Claude scratchpad) fail: use `%TEMP%\ops-tools` or another short path.
- Hook/CLI output with Arabic: set `[Console]::OutputEncoding = New-Object Text.UTF8Encoding $false`.

**Processes and tests**
- When stopping a server by command line, exclude `$PID` (your own shell matches too).
- Pester 3.4 is built in. Run suites in a fresh process (`powershell -NoProfile -Command "Invoke-Pester ..."`) so
  module changes are really reloaded. Point tests at temp data with env vars (e.g. `STRANOTE_CONFIG`, `STRANOTE_LEARN_DIR`).
- Execution policy is Restricted: launch with `-ExecutionPolicy Bypass`.
