# LINEAR_INSPIRED_UI_UX.md

> Implementation spec for Claude Code. A reusable design language: **~80% Linear** (structure, density, restraint, keyboard-first) and **~20% ChatGPT** (conversation, composer, AI states).
> Research date: **2026-10-19**. Sources: live inspection of linear.app and chatgpt.com in Chrome (logged-in accounts), computed-style extraction via DevTools-equivalent JavaScript, plus Linear's official redesign write-up.

---

## 0. How to use this document (read first)

**Evidence tags** — every rule carries one of these:

| Tag | Meaning |
|---|---|
| **[O]** | **Observed & measured.** Read from computed styles or CSS custom properties in the live app at 1920×861 CSS px, DPR 1. Exact. |
| **[V]** | **Visually observed.** Seen in screenshots, not measured numerically. |
| **[D]** | Stated in **official documentation**. |
| **[I]** | **Inferred** from observations (pattern, likely intent). |
| **[R]** | **Recommendation** for implementations of this spec. Not a claim about Linear/ChatGPT. |
| **[U]** | **Uncertain / not verified.** Needs inspection before relying on it. |

**Precedence when adopting into an existing product** (non-negotiable):

1. The product's existing **brand color, logo, terminology, information architecture, business workflows and functional behavior win**. This spec changes *how things look and feel*, not *what the product does*.
2. Use this spec's **structure, spacing, density, typography scale, state model and interaction patterns**.
3. Swap Linear's indigo accent for the product's **primary brand color** (validate contrast — §11).
4. Never copy Linear/ChatGPT logos, illustrations, icon sets, product names, or product-specific terms ("Issues", "Cycles", "Triage", "Ask Linear", "Think", etc.) unless they already exist in the target product.

---

## 1. Executive summary & design philosophy

Linear's interface is a **calm, near-monochrome tool surface**: one neutral hue family (LCH hue ≈282 light / ≈272 dark, chroma ≤1.5) carries almost all of the UI, one accent (indigo `#6d78d5`) marks focus, selection and the single primary action, and status/priority colors appear only as small glyphs. Density comes from **13px UI text, 28px controls, 32px menu rows, 44px list rows**, and hierarchy comes from **weight and gray level, not size** (only four sizes cover >90% of the UI: 12/13/15/24px).

The defining structural idea is the **inset content panel**: the app background *is* the sidebar color, and the main view is a single raised panel (8px inset, 12px radius, 1px hairline border, near-invisible shadow) — Linear's documented "inverted-L chrome" [D].

Interaction is **keyboard-first with progressive disclosure**: every action exists in a command palette, a context menu (with shortcut hints), and a single-key shortcut; secondary controls (row checkboxes, item actions) appear only on hover; tooltips teach shortcuts.

ChatGPT contributes the **conversation model**: a single centered ~768px reading column, assistant answers as bubble-less prose, user turns as compact right-aligned bubbles, an elevated pill composer that grows with content, per-message action rows revealed under the answer, and a scroll-to-latest affordance. Linear's own Agent screen [O] shows these same patterns rendered in Linear's restrained language — it is the best bridge between the two references and is used as the template for AI surfaces in §9.

**Design philosophy in five rules**

1. **Neutral first, color with meaning.** Gray does the work; color = state, identity or the one primary action.
2. **Hierarchy through weight and tone, not size.** Prefer 13px/500 vs 13px/450 + text-tertiary over bigger fonts.
3. **One surface, few elevations.** Base panel → raised (cards/inputs) → floating (menus/palette/dialogs). No other shadows.
4. **Everything reachable three ways.** Pointer, command palette, shortcut. Show the shortcut wherever the action is shown.
5. **Calm by default, detail on demand.** Hover-reveal, disclosure toggles, side panels; never pre-render every control.

---

## 2. Research methodology, inspected screens & limitations

### 2.1 Method
- Inspected live apps in the user's Chrome (Linear workspace "Ahmedgaid01", ChatGPT personal account). Viewport **1920×861 CSS px, devicePixelRatio 1**, Windows/Chromium.
- Extracted values with `getComputedStyle`, `getBoundingClientRect`, `elementFromPoint`, pseudo-element styles (`::before`) and the full list of `:root` CSS custom properties (Linear: 363 variables).
- Tested interactions with real mouse/keyboard events: hover, right-click, arrow keys, Escape, shortcut keys, theme switch.
- Converted Linear's LCH values to sRGB hex (D50→D65 Bradford). Conversions were validated against Linear's own hex variables (e.g. `lch(97.94 0.5 282)` → `#f9f9fa` = `--bg-base-color-light`; `lch(53 52.26 286.91)` → `#6d78d5` = `--focus-ring-color`).
- Computed WCAG 2.x contrast ratios for key pairs (§11).
- Official source consulted: Linear, *"How we redesigned the Linear UI"* (LCH theme generation, Inter/Inter Display, inverted-L chrome).

### 2.2 Screens & states inspected

**Linear** (light, plus dark where noted)
| Screen / state | What was verified |
|---|---|
| Team overview page | Sidebar, header, pill tabs, page title, empty description placeholder |
| Team issues — **board** layout | Column headers, cards, chips, card shadow; **dark theme** values |
| App loading state | Panel frame + centered logo mark skeleton |
| **Command palette** (Ctrl+K) | Size, shadow, rows, highlight, group labels, kbd hints, typing filter, nested sub-command (theme), empty result; **dark** values; ↓ key moves focus |
| **Theme switch** Light → Dark → Light | All neutral tokens in both themes (account restored to Light) |
| My issues — **list** layout | Row height, group headers, hover state (row highlight + checkbox reveal), sub-issue tree lines, muted parent row |
| **Context menu** (right-click row) + **submenu** (Priority) | Menu size/shadow, item metrics, shortcuts, submenu filter input, Esc closes one level at a time |
| **Issue detail** page | Title/body typography, content column, properties side panel, activity, comment box, prev/next "3 / 6" pager |
| **Help menu** (`?`) and **Keyboard Shortcuts** side sheet | Sheet size, scrim, search input focus ring; full shortcut catalogue |
| Sidebar toggle (`[`) | Sidebar fully hides; panel keeps 8px inset |
| **New issue dialog** (`C`) | Dialog size/radius/shadow, title/desc inputs, property chips, switch, primary button (closed with Esc, nothing created) |
| **Settings → Preferences** | 640px settings column, grouped cards, rows, selects, switches, settings nav + search |
| **Inbox** empty state | Split pane (400px list), empty texts, line illustration |
| **Agent** (Linear's AI chat): empty + an existing conversation | Composer, recent chats list with unread dot, user bubble, assistant prose, "Worked for N seconds" reasoning disclosure, inline entity chips, embedded issue list, hover card, feedback actions |
| Tooltips | Light tooltip with kbd hint (`Add Filter F`, `Go to inbox G then I`) |

**ChatGPT** (light only)
| Screen / state | What was verified |
|---|---|
| New chat (empty) | Greeting, pill composer, sidebar, top segmented control |
| Existing conversation (Arabic + English) | User bubble, assistant typography (p, h2, h3, lists, hr, blockquote, inline code, citation chip), timestamp, scroll-to-bottom button, disclaimer, **RTL rendering** |
| Composer "+" menu | Popover metrics, rows with inline descriptions |
| Search chats dialog | Size, radius, shadow, rows, no backdrop dimming |
| Composer typing state | Composer grows (52→102px), mic/voice swaps to Send |
| One new test chat (sent with the user's permission) | Post-response action row, tooltip on action |

### 2.3 Limitations (honest list)
- **Single viewport only.** The browser window was not resized (it is the user's live window). Responsive behavior below ~1900px is **not observed**; §11 uses Linear's media queries found in CSS + recommendations.
- **ChatGPT streaming was not captured.** The test reply completed within ~1s, faster than screenshot latency. Stop button, streaming caret/cursor, and partial-render behavior are **[U]**.
- **ChatGPT dark theme not inspected** (would require changing the user's settings; not requested).
- **Animation curves/durations** were read from stylesheet rules (counts only); most Linear styles are runtime-generated atomic classes, so per-component timings are mostly **[U]**, except buttons (`.15s` on border/background/color/opacity [O]).
- **Toasts, error banners, form validation errors, drag-and-drop, date pickers, tables (spreadsheet-style)** were not triggered — avoided creating/modifying data.
- The modal **backdrop dimming** behind Linear's new-issue dialog is visible [V] but its implementing element was not identified [U].
- Mobile apps / touch behavior not inspected.
- Linear's inline styles use LCH; values below are given in LCH (exact) **and** hex (converted, ±1 per channel).

---

## 3. Observed vs inferred vs recommended (summary map)

| Topic | Observed [O]/[V]/[D] | Inferred [I] | Recommended adaptation [R] |
|---|---|---|---|
| Color system | Neutral LCH scale, hue 282 (light)/272 (dark), chroma 0–1.5; single indigo accent `#6d78d5`; themes generated from base/accent/contrast [D] | Neutrals are slightly cool-tinted on purpose to look "clean" without reading as blue | Generate neutrals from the brand hue at chroma ≤2; keep accent = brand primary |
| Shell | Sidebar 244px; app bg = sidebar color; main panel inset 8px, radius 12, 1px border | Inset panel creates calm "object on desk" depth without heavy shadows | Use as default desktop shell |
| Typography | Inter Variable; 12/13/15/18/24px; weights 400/450/500/600; headings Inter Display [D] | 450 is the "reading" weight; 500 the "label" weight | Ship Inter Variable; if brand font differs, keep the scale and weights |
| Controls | 28px icon buttons & pill tabs, 24px chips, 32px menu rows, 44px list rows | Two-step size ladder (24/28) keeps rows aligned | Enforce component heights via tokens |
| Elevation | 3 levels: panel (hairline), raised (ring + 1–3px), floating (9/48px) | Shadows are near-invisible in light, replaced by 1px rings in dark | Never invent a 4th elevation |
| Keyboard | Ctrl+K palette, single-key and `G then X` chords, shortcut hints in tooltips/menus | Shortcuts are a teaching surface, not a hidden power feature | Ship palette + `?`/Ctrl+/ shortcut sheet from day 1 |
| AI chat | 768px column, bubble-less assistant, right user bubble, pill composer (ChatGPT); Linear Agent: same with 8px radius bubble and reasoning disclosure | — | Use Linear Agent look with ChatGPT behaviors |

---

## 4. Design tokens

All CSS below is **ready to paste**. Values marked [O] are measured; [R] are starting recommendations. Token names are generic (not Linear's).

### 4.1 Color — light theme

| Token | LCH (exact) | Hex | Tag | Use |
|---|---|---|---|---|
| `--color-app-bg` | 94.44 0.5 282 | `#efeff0` | [O] | Window background **and** sidebar background |
| `--color-panel` | 97.94 0.5 282 | `#f9f9fa` | [O] | Main inset content panel |
| `--color-surface-raised` | 100 0 282 | `#ffffff` | [O] | Cards, inputs, menus, palette, dialogs, tooltips, comment box |
| `--color-bg-secondary` | 92.44 0.5 282 | `#e9e9ea` | [O] | Secondary fills |
| `--color-bg-tertiary` | 90.94 0.5 282 | `#e5e5e6` | [O] | Pressed/stronger fills |
| `--color-hover` | 94.44 0.5 282 | `#efeff0` | [O] | List-row hover, group header background |
| `--color-hover-nav` | 91.64 0.5 282 | `#e7e7e8` | [O] | Sidebar item hover |
| `--color-selected-nav` | 89.54 0.5 282 | `#e1e1e2` | [O] | Sidebar item selected |
| `--color-highlight-menu` | 95 0 282 | `#f1f1f1` | [O] | Focused option in command palette |
| `--color-btn-ghost-hover` | 95.88 0.16 282 | `#f2f2f2` | [O] | Icon-button hover |
| `--color-border-subtle` | 95.24 0 282 | `#f1f1f1` | [O] | Panel border, faint dividers |
| `--color-border` | 88.49 0 282 | `#dedede` | [O] | Default divider, editor hairline (`--editor-bg-border-thin: #dedede`) |
| `--color-border-strong` | 84.44 0 282 | `#d3d3d3` | [O] | Tree lines, outlined chips (on panel) |
| `--color-border-popover` | 90.55 0 282 | `#e4e4e4` | [O] | Menus, palette, dialog, tooltip border |
| `--color-border-control` | 86.5 0 282 | `#d8d8d8` | [O] | Chips, text inputs |
| `--color-text-primary` | 9.794 0 282 | `#1b1b1b` | [O] | Titles, primary content |
| `--color-text-secondary` | 19.588 1.25 282 | `#2f2f31` | [O] | Body text, control labels |
| `--color-text-nav` | 37.776 1.25 282 | `#59595b` | [O] | Unselected sidebar labels, section headers |
| `--color-text-tertiary` | 39.176 1.25 282 | `#5c5c5e` | [O] | Metadata, IDs, dates, group labels, descriptions |
| `--color-text-quaternary` | 64.64 1.25 282 | `#9c9d9f` | [O] | Placeholder-only / disabled (fails AA for text — §11) |
| `--color-placeholder` | 66 1 282 | `#a0a1a2` | [O] | Input placeholders |
| `--color-accent` | 53 52.26 286.91 | `#6d78d5` | [O] | Focus ring, primary button, toggle on, unread dot, send button |
| `--color-on-accent` | 100 5 286.91 | `#fdfcff` | [O] | Text/icon on accent |
| `--color-selection` | — | `color-mix(in srgb, #5b5c5e 20%, transparent)` | [O] | Selected rows (passive) |
| `--color-selection-active` | — | `color-mix(in srgb, #6d78d5 40%, transparent)` | [O] | Selected rows (active/focused) |
| `--color-scrim` | — | `rgb(0 0 0 / .25)` | [O] | Behind side sheets |

**Semantic hues** (status/priority/labels — observed in Linear's variable set, used only as small glyphs/dots) [O]:

| Role | Base | Strong/text | Subtle bg |
|---|---|---|---|
| Blue/info | `#007eff` | `#006cdb` | `#e3f1ff` |
| Teal | `#00aabd` | `#007689` | `#e0edf1` |
| Green/success | `#32ae4b` | `#007818` | `#e3eee5` |
| Yellow/warning | `#e0b100` | `#825f00` | `#f7eee1` |
| Orange/urgent | `#f26428` | `#b93200` | `#fae6e3` |
| Red/danger | `#e33e46` | `#c31930` | `#f7e3e4` |
| Indigo/brand | `#5e6ad2` | `#4f5dc4` | `#e4e5f2` |

> [I] Base = icon/dot fill, Strong = text on subtle bg, Subtle = tinted chip background. Exact role assignments in Linear were not verified; treat the mapping as [R].

### 4.2 Color — dark theme ("Dark", measured after switching the account theme)

| Token | LCH (exact) | Hex | Tag |
|---|---|---|---|
| `--color-app-bg` | 2.595 0.4 272 | `#09090a` | [O] |
| `--color-panel` | 5.52 0.4 272 | `#121213` | [O] |
| `--color-bg-secondary` | 7.32 0.85 272 | `#161617` | [O] |
| `--color-bg-tertiary` | 8.22 1.3 272 | `#17181a` | [O] |
| `--color-surface-raised` (cards) | 9.232 0.85 272 | `#1a1a1b` | [O] |
| `--color-surface-floating` (palette) | 12.72 0.85 272 | `#212122` | [O] |
| `--color-selected-nav` | 13.845 1.3 272 | `#232325` | [O] |
| `--color-selected-tab` | 16.706 0.98 272 | `#29292b` | [O] |
| `--color-highlight-menu` | 20.82 1.3 272 | `#313234` | [O] |
| `--color-border-subtle` | 9.84 1.48 272 | `#1a1b1d` | [O] |
| `--color-border` | 14.16 1.48 272 | `#232426` | [O] |
| `--color-border-strong` | 16.32 1.48 272 | `#28282b` | [O] |
| `--color-border-control` | 20.03 1.93 272 | `#2f3033` | [O] |
| `--color-border-popover` | 21.36 1.93 272 | `#323336` | [O] |
| `--color-text-primary` | 100 0 272 | `#ffffff` | [O] |
| `--color-text-secondary` | 90.45 1.2 272 | `#e3e4e6` | [O] |
| `--color-text-tertiary` | 61.80 1.2 272 | `#959597` | [O] |
| `--color-text-quaternary` | 36.98 1.2 272 | `#565759` | [O] |
| `--color-accent` | 53 52.26 286.91 | `#6d78d5` | [O] (focus ring var unchanged in dark) |

Key dark-mode rule [O]: **elevation goes lighter** (app `#09090a` < panel `#121213` < card `#1a1a1b` < palette `#212122`), and **shadows are replaced by a 1px white ring at ~5% alpha** (`0 0 0 1px lch(100 0 0 / .048)`).

Linear also offers "Pure Light", "Magic Blue", "Classic Dark", "System preference" [O] — [R] implement **Light, Dark, System** only unless the product needs more.

### 4.3 Typography tokens

| Token | Value | Tag |
|---|---|---|
| `--font-sans` | `"Inter Variable", "SF Pro Display", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, Cantarell, "Open Sans", "Helvetica Neue", sans-serif` | [O] |
| `--font-display` | `"Inter Display"` for headings | [D] |
| `--font-mono` | `"Berkeley Mono", "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace` | [O] (Berkeley Mono is commercial — [R] use `ui-monospace, "JetBrains Mono", "SFMono-Regular", Consolas, monospace`) |
| `--font-emoji` | `"Apple Color Emoji","Segoe UI Emoji","Segoe UI Symbol","Noto Color Emoji"` | [O] |
| Weights | `400` regular, `450` reading, `500` label/emphasis, `600` headings | [O] |
| Editor | `font-size: .9375rem` (15px), `line-height: 1.6`, `font-weight: 450`, `letter-spacing: -.0067em` | [O] (CSS vars) |

### 4.4 Spacing, sizing, radius

| Token | Value | Evidence |
|---|---|---|
| Spacing base | **4px grid**; common steps 2, 4, 6, 8, 10, 12, 16, 24, 32 | [O] paddings seen: 2/4/5/6/8/9/10/12/14/16/18 → [R] snap to 4px grid except 6/10/14 for optical alignment |
| `--size-control-sm` | 24px (chips, small icon buttons, send button in Agent) | [O] |
| `--size-control` | 28px (icon buttons, tabs, nav items, primary button, select-ish buttons) | [O] |
| `--size-control-lg` | 30–32px (settings selects 30, menu rows 32) | [O] |
| `--size-input-lg` | 40–44px (palette input, sheet search) | [O] |
| `--size-row` | 44px list row; 36px group header | [O] |
| `--size-icon` | 14px in controls; 16px nav icons | [O] |
| `--sidebar-width` | 244px | [O] `--sidebar-width:244px` |
| `--panel-inset` | 8px (top/right) | [O] |
| `--scrollbar-width` | 10px | [O] |
| `--radius-xs` | 3–4px (kbd, inline entity chips) | [O] |
| `--radius-sm` | 6px (editor blocks) | [O] `--editor-block-radius:6px` |
| `--radius-md` | 8px (controls, nav items, rows, cards, tooltips, `--control-border-radius:8px`) | [O] |
| `--radius-lg` | 10px (settings groups, inputs, Agent composer) | [O] |
| `--radius-xl` | 12px (panel, menus, palette, sheet) | [O] |
| `--radius-dialog` | 21px (create dialog) | [O] — [R] use 16px unless matching Linear exactly |
| `--radius-pill` | 9999px (buttons, tabs, chips) | [O] `--radius-rounded:9999px` |

### 4.5 Elevation (shadows) — exact light values [O]

```css
--shadow-panel:    0 3px 6px -2px rgb(0 0 0 / .02), 0 1px 1px rgb(0 0 0 / .04);              /* + 1px border-subtle */
--shadow-raised:   0 0 0 1px rgb(0 0 0 / .029), 0 3px 6px -2px rgb(0 0 0 / .02), 0 1px 1px rgb(0 0 0 / .04); /* cards, settings groups */
--shadow-menu:     0 6px 18px rgb(0 0 0 / .02), 0 3px 9px rgb(0 0 0 / .04), 0 1px 1px rgb(0 0 0 / .04);       /* context menu, side sheet */
--shadow-floating: 0 9px 48px rgb(0 0 0 / .08), 0 6px 24px rgb(0 0 0 / .10), 0 1px 1px rgb(0 0 0 / .04);      /* palette, dialog, submenu */
--shadow-inset:    inset 0 1px 1px rgb(0 0 0 / .067), inset 0 1px 3px rgb(0 0 0 / .067), inset 0 2px 5px rgb(0 0 0 / .1);
```
Dark [O]:
```css
--shadow-panel:    0 .5px 1px 1px rgb(0 0 0 / .3);
--shadow-raised:   0 0 0 1px rgb(255 255 255 / .048), 0 .5px 1px 1px rgb(0 0 0 / .3);
--shadow-floating: 0 4px 40px rgb(0 0 0 / .1), 0 3px 20px rgb(0 0 0 / .125), 0 3px 12px rgb(0 0 0 / .125), 0 2px 8px rgb(0 0 0 / .125), 0 1px 1px rgb(0 0 0 / .125);
```

### 4.6 Motion

| Token | Value | Tag |
|---|---|---|
| `--duration-fast` | 150ms — buttons: `transition: border .15s, background-color .15s, color .15s, opacity .15s` | [O] |
| Other durations in stylesheets | 100ms, 200ms, 250ms, 300ms, 400ms (most frequent: 150/200/400) | [O] (not mapped to components) |
| Easing | `ease-out` most common; `cubic-bezier(.25,.46,.45,.94)` for opacity fades | [O] |
| Reduced motion | `@media (prefers-reduced-motion: reduce)` rules exist | [O] |
| Hover gating | Hover styles wrapped in `@media (any-hover: hover) and (any-pointer: fine)` (91 rules) | [O] |
| Recommended | Hover/press 120–150ms; menus/popovers in 150ms (opacity + 2–4px translate/scale .98→1); dialogs 200ms; side sheets 250ms; never > 300ms for UI response | [R] |

### 4.7 Paste-ready token file

```css
:root, [data-theme="light"] {
  --color-app-bg:#efeff0; --color-panel:#f9f9fa; --color-surface-raised:#ffffff; --color-surface-floating:#ffffff;
  --color-bg-secondary:#e9e9ea; --color-bg-tertiary:#e5e5e6;
  --color-hover:#efeff0; --color-hover-nav:#e7e7e8; --color-selected-nav:#e1e1e2; --color-highlight-menu:#f1f1f1; --color-btn-ghost-hover:#f2f2f2;
  --color-border-subtle:#f1f1f1; --color-border:#dedede; --color-border-strong:#d3d3d3; --color-border-control:#d8d8d8; --color-border-popover:#e4e4e4;
  --color-text-primary:#1b1b1b; --color-text-secondary:#2f2f31; --color-text-nav:#59595b; --color-text-tertiary:#5c5c5e; --color-text-quaternary:#9c9d9f; --color-placeholder:#a0a1a2;
  --color-accent: var(--brand-primary, #6d78d5); --color-on-accent:#ffffff;
  --color-focus-ring: var(--color-accent);
  --color-selection: color-mix(in srgb, #5b5c5e 20%, transparent);
  --color-selection-active: color-mix(in srgb, var(--color-accent) 40%, transparent);
  --color-scrim: rgb(0 0 0 / .25);
  --shadow-panel: 0 3px 6px -2px rgb(0 0 0/.02), 0 1px 1px rgb(0 0 0/.04);
  --shadow-raised: 0 0 0 1px rgb(0 0 0/.029), 0 3px 6px -2px rgb(0 0 0/.02), 0 1px 1px rgb(0 0 0/.04);
  --shadow-menu: 0 6px 18px rgb(0 0 0/.02), 0 3px 9px rgb(0 0 0/.04), 0 1px 1px rgb(0 0 0/.04);
  --shadow-floating: 0 9px 48px rgb(0 0 0/.08), 0 6px 24px rgb(0 0 0/.10), 0 1px 1px rgb(0 0 0/.04);
}
[data-theme="dark"] {
  --color-app-bg:#09090a; --color-panel:#121213; --color-surface-raised:#1a1a1b; --color-surface-floating:#212122;
  --color-bg-secondary:#161617; --color-bg-tertiary:#17181a;
  --color-hover:#1a1a1b; /* [R] not measured */ --color-hover-nav:#1d1d1f; /* [R] */ --color-selected-nav:#232325; --color-highlight-menu:#313234; --color-btn-ghost-hover:#232325; /* [R] */
  --color-border-subtle:#1a1b1d; --color-border:#232426; --color-border-strong:#28282b; --color-border-control:#2f3033; --color-border-popover:#323336;
  --color-text-primary:#ffffff; --color-text-secondary:#e3e4e6; --color-text-nav:#c7c8ca; /* [R] */ --color-text-tertiary:#959597; --color-text-quaternary:#565759; --color-placeholder:#6b6f76; /* [R] borrowed from Linear's dark loading-screen content color; dark placeholder not measured */
  --color-selection-active: color-mix(in srgb, var(--color-accent) 40%, transparent);
  --shadow-panel: 0 .5px 1px 1px rgb(0 0 0/.3);
  --shadow-raised: 0 0 0 1px rgb(255 255 255/.048), 0 .5px 1px 1px rgb(0 0 0/.3);
  --shadow-menu: 0 0 0 1px rgb(255 255 255/.04), 0 4px 24px rgb(0 0 0/.3); /* [R] */
  --shadow-floating: 0 4px 40px rgb(0 0 0/.1), 0 3px 20px rgb(0 0 0/.125), 0 3px 12px rgb(0 0 0/.125), 0 2px 8px rgb(0 0 0/.125), 0 1px 1px rgb(0 0 0/.125);
}
:root {
  --font-sans:"Inter Variable","Inter",-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,"Helvetica Neue",sans-serif;
  --font-mono:ui-monospace,"JetBrains Mono","SFMono-Regular",Consolas,"Liberation Mono",monospace;
  --radius-xs:4px; --radius-sm:6px; --radius-md:8px; --radius-lg:10px; --radius-xl:12px; --radius-dialog:16px; --radius-pill:9999px;
  --size-control-sm:24px; --size-control:28px; --size-menu-row:32px; --size-row:44px; --size-group-header:36px;
  --sidebar-width:244px; --panel-inset:8px;
  --duration-fast:150ms; --duration-base:200ms; --duration-slow:250ms; --ease-out:cubic-bezier(.25,.46,.45,.94);
}
```

---

## 5. Layout & spacing rules

### 5.1 App shell (desktop) [O]
```
┌──────────────┬──────────────────────────────────────────────────┐  ← window bg = --color-app-bg
│ Sidebar 244  │ ┌──────────── Main panel ───────────────────────┐ │  8px top/right inset
│ (no border,  │ │ Header 44px (breadcrumb · actions)            │ │  radius 12, 1px border-subtle,
│  same color  │ │ View bar 43px (pill tabs · filter/display)    │ │  --shadow-panel
│  as window)  │ │ Content (scrolls inside the panel)            │ │
│              │ └───────────────────────────────────────────────┘ │
│              │ Optional bottom utility bar 36px                  │
└──────────────┴──────────────────────────────────────────────────┘
```
- Sidebar has **no border or shadow**; separation comes from the panel's edge [O].
- Panel spans `x = 244 → viewport − 8`. Panel scrolls internally; the window never scrolls [O].
- Toggling the sidebar (`[`) hides it entirely; panel expands but **keeps its 8px inset** [O].
- Header row: 44px, title/breadcrumb text 13px/500 `text-secondary`, actions as 28px icon buttons on the right [O].
- View bar: 43px, left = pill tabs (28px) with 8px gaps; right = icon buttons (filter, display, side panel) [O].

### 5.2 Content widths [O]
| Context | Width |
|---|---|
| Document/detail column (issue) | ~790px text column, starting ~213px inside the panel [O]; properties rail starts ~1064px into the panel (width ≈ 240px [V]) |
| Settings column | 640px, centered |
| Agent/AI chat column | ~810px (composer 712px on empty state) |
| ChatGPT thread / composer | 768px (`--thread-content-max-width: 48rem`) |
| Command palette | 720px (both Linear and ChatGPT search!) |
| Create dialog | 750px |
| Side sheet | 360px, inset 12px from edges |
| Split list pane (Inbox) | 400px |
| Board column | 324px card + 24px gap (348px pitch) |

[R] Rule: **reading columns 640–800px; overlays 720px; side sheets 360px; never full-bleed text.**

### 5.3 Spacing rules [R, derived from O]
- Inside controls: horizontal padding 8–10px (pills 10px, chips 8px, menu items 14px left / 18px right).
- Between sibling controls in a toolbar: 4–8px.
- Section header → content: 12px; section → section: 24–32px (settings uses ~40px between groups [V]).
- List rows do **not** use dividers; rows are separated by height (44px) and hover fill [O].
- Group headers are tinted bars (36px, `--color-hover`, radius 8) instead of lines [O].
- Indentation for hierarchy: 19–20px (sidebar sub-items [O]); sub-issue tree uses 1px `--color-border-strong` connector lines [O].

---

## 6. Typography & visual hierarchy

### 6.1 Type scale [O unless noted]

| Role | Size / line-height | Weight | Color | Example |
|---|---|---|---|---|
| Page title (detail) | 24 / 32px, `letter-spacing:-0.16px` | 600 | text-primary | Issue title |
| Page title (settings) | 24px | 500 | text-primary | "Preferences" |
| Dialog title input | 18px | 600 | text-primary | "Issue title" |
| Section heading | 15px | 600 (detail) / 500 (settings) | text-primary | "Activity", "General" |
| Body / description / chat | 15 / 24px | 450 | text-secondary | Issue description, Agent messages |
| UI label (nav, list title, menu, header) | 13px | 500 (titles, nav), 450 (menu items, palette rows) | primary / nav | Sidebar items, row titles |
| Settings row label | 13px | 500 | text-primary | "Display names" |
| Metadata / description | 12px | 450 | text-tertiary | Dates, IDs (13/450 in lists), settings descriptions |
| Chips, buttons, tabs, tooltips | 12px | 500 (buttons/tabs), 450 (chips/tooltips) | secondary/tertiary | "Create issue", "Backlog" |
| Group / section label | 12px | 500 | text-nav / tertiary | "Your teams", palette "Issues" |
| Keyboard hint | 12px | 400–500 | tertiary, in `kbd` | `C`, `G then I` |

### 6.2 Hierarchy rules
1. **Max two sizes per component.** A list row uses 13px only; hierarchy = weight 500 (title) vs 450 + tertiary (ID/date) [O].
2. **Size jumps are reserved for page titles (24px).** No 32px+ headings anywhere in app UI [O]. Marketing pages are out of scope.
3. **Gray ladder:** primary (titles) → secondary (body) → tertiary (meta) → quaternary (placeholder/disabled only).
4. **IDs and numbers** use tertiary color, tabular figures recommended (`font-variant-numeric: tabular-nums`) [R].
5. Negative letter-spacing only on ≥18px text (−0.16px at 24px [O]; editor −0.0067em [O]).
6. ChatGPT prose differs [O]: 16/26px body, h2 24/32 600, h3 20/28 600. [R] For long-form AI answers, use 15/24 (Linear) in dense apps and 16/26 when the chat is the primary surface.

---

## 7. Component specifications & interaction-state matrices

General state rules [O/R]:
- **Hover** = background fill one step darker (light) / lighter (dark). Never change size, never add shadow on hover (board cards keep the same shadow on hover [O]).
- **Focus-visible** = `outline: 1px solid var(--color-focus-ring)` (Linear `--focus-ring-outline: 1px solid #6d78d5` [O]); [R] add `outline-offset: 1px` on filled controls and use 2px when the 1px ring is <3:1 against adjacent colors.
- **Selected** = stronger neutral fill (nav) or accent-tinted fill (multi-select rows).
- **Disabled** = text-quaternary + `pointer-events:none`; no opacity <0.5 on text.
- **Pressed** = bg-tertiary fill [R].
- **Cursor**: Linear defaults to `cursor: default` on interactive elements (`--pointer: default`; "Use pointer cursors" preference is off by default [O]). [R] Use `default` for app chrome and `pointer` for real hyperlinks; make it a preference only if the product already has one.

### 7.1 Buttons

| Variant | Height | Radius | Padding | Font | Fill / Border | Tag |
|---|---|---|---|---|---|---|
| Primary | 28 | pill | 0 10px | 12/500 | `--color-accent`, text on-accent, `--shadow-panel` | [O] |
| Secondary (outlined) | 28 | pill | 0 10px | 12/500 | raised bg + 1px ring (`0 0 0 1px rgb(0 0 0/.1)`) | [O]/[I] |
| Ghost icon | 28×28 | pill | 0 2px | icon 14px | transparent → `--color-btn-ghost-hover` | [O] |
| Small icon (message actions) | 24×24 | pill | — | 14px icon | transparent | [O] |
| Toolbar "send" | 24×24 | 12px | — | arrow 14px | accent | [O] |

| State | Primary | Ghost/Secondary |
|---|---|---|
| Default | accent fill | transparent / raised |
| Hover | accent −4 L (darker) [R] | `--color-btn-ghost-hover` [O] |
| Focus-visible | 1px accent ring + 1px offset [R] | 1px accent ring [O] |
| Pressed | accent −8 L [R] | `--color-bg-tertiary` [R] |
| Disabled | accent at 40% opacity, no shadow [R] | text-quaternary [R] |
| Loading | keep width; replace label with 12px spinner; `aria-busy` [R] | same |
| Transition | 150ms on border, bg, color, opacity [O] | same |

Rules: one primary button per view region [R]; primary sits bottom-right of dialogs [O]; label is a verb phrase ("Create issue") [O].

### 7.2 Sidebar navigation item [O]
- 28px tall, radius 8, full width minus 12px side margins (220px), icon 16px + 8px gap, label 13/500.
- Colors: default text `--color-text-nav`; hover bg `--color-hover-nav`; selected bg `--color-selected-nav` + text-primary.
- Trailing count (e.g. Drafts "1") right-aligned, 12–13px tertiary.
- Section headers ("Favorites", "Your teams") 12/500 tertiary with ▾/▸ disclosure; collapsible.
- Nested items indent ~19px.
- Hover tooltip shows the shortcut ("Go to inbox · G then I") [O].
- Top: workspace switcher (avatar + name + chevron) with search and compose icon buttons; bottom: small "What's new" card [O]. [R] Use the top/bottom slots for the product's own switcher/account and announcements.

| State | Bg | Text |
|---|---|---|
| Default | transparent | text-nav |
| Hover | hover-nav | text-primary |
| Selected | selected-nav | text-primary |
| Focus-visible | — | + 1px accent outline |
| Drag-over (reorder) | [U] | [U] |

### 7.3 Pill tabs / segmented view switcher [O]
28px tall, pill radius, 0 10px padding, 12/500, text-tertiary. Unselected: raised/near-white fill with 1px hairline; selected: neutral fill (light ≈ bg-secondary [V]; dark `#29292b` [O]) with text-primary. ChatGPT's top "Chat / Work" control is a segmented pill with a white thumb on a gray track [V].

### 7.4 Inputs [O]
| Input | Height | Radius | Padding | Font | Border |
|---|---|---|---|---|---|
| Sidebar search | 28 | 8 | 6 25 6 32 (icon left) | 13/500 | raised + `--shadow-panel` |
| Sheet search | 44 | 10 | 12 25 12 36 | 13/500 | 1px `--color-border-control` |
| Palette input | ~40 | 12 (top) | 11 112 11 12 | 13/400 | none (lives inside palette) |
| Select button | 30 | 8 | 1 28 1 10 (chevron right) | 13/400 | 1px hairline |
| Title (inline) | auto | — | 0 | 18/600 or 24/600 | none — **borderless inline editing** |
| Description (inline) | auto | — | 0 | 15/450 | none |
| Switch | 30×20 (settings), 22×14 (compact) | pill | — | — | off = neutral gray, on = accent |

State matrix:
| State | Visual |
|---|---|
| Default | border-control or none (inline fields) |
| Hover | border one step darker [R] |
| Focus | `outline: 1px solid accent` [O] (computed `lch(53 52.26 286.91) solid 1px`) |
| Invalid | border + text `#c31930` (red strong), message 12px below [R] |
| Disabled | bg-secondary, text-quaternary [R] |
| Placeholder | `--color-placeholder`; short, verb-led ("Add a description…", "Leave a comment…") [O] |

### 7.5 Chips / property pills [O]
24px tall, radius pill (48px), 0 8px padding (6px left when an icon leads), 12/450 text-tertiary (500 in dialogs), 1px `--color-border-control` (rendered as a 1px ring via `::after` in the dialog). Leading 12–14px glyph for status/priority/label color dot. Click opens the same filterable submenu as the context menu [I]. Never use filled saturated chips [R].

### 7.6 Badges & status glyphs [V]
- Status = 14px circular glyph (dashed = backlog, empty = todo, half = in progress, check = done) colored by semantic hue.
- Priority = 3-bar signal icon; urgent = orange filled square with "!".
- Counts = plain number in tertiary next to group name (no pill) [O].
- Unread = 8px accent dot [O].
[R] Always pair color with shape/text (never color-only).

### 7.7 List row (primary data view) [O]
- Height 44px, radius 8, full panel width minus 8px margins.
- Columns left→right: hover-checkbox gutter · priority · ID (13/450 tertiary) · status glyph · title (13/500 primary) · flexible space · chips (project/labels) · assignee avatar (16–18px) · date (12/450 tertiary).
- Hover: `::before` fill `--color-hover`; **checkbox appears** in left gutter [O].
- Selected (X key/checkbox): `--color-selection` / active `--color-selection-active` [O vars].
- Muted rows (context-only parent): text dims to tertiary [O].
- Sub-items indented with 1px tree connectors [O].
- Group header: 36px, `--color-hover` bg, radius 8, collapse caret, label 13/500, count tertiary, trailing "+" icon button [O].

| State | Treatment |
|---|---|
| Default | transparent |
| Hover | hover fill + reveal checkbox and trailing actions |
| Keyboard focus (J/K) | same fill as hover + [R] 2px accent left indicator or outline |
| Selected | selection tint, checkbox checked |
| Dragging | [U] |
| Loading | skeleton row: 3 gray bars at 13px height [R] |

### 7.8 Card (board) [O]
324px wide, radius 8, bg `--color-surface-raised`, `--shadow-raised`; content padding ≈12px; rows: ID (12/450 tertiary) + avatar · status + title (13/500, 2-line clamp) · chips row (24px) · footer meta ("Created Sep 20", 12/450 tertiary). Hover does **not** add elevation [O]. Columns: header 13/500 with count, "…" and "+" ghost icons, no column background [O].

### 7.9 Menus (dropdown & context) [O]
- Container: content width (≈180–210px), radius 12, `--color-surface-floating`, 1px `--color-border-popover`, `--shadow-menu`. Padding ≈4px [V].
- Item: 32px, padding 0 18px 0 14px, icon 14–16px + 8px gap, label 13/450, trailing shortcut in `kbd` style (12/500 tertiary) and/or ▸ for submenus.
- Highlight: inset rounded fill (radius 8, ≈2px vertical inset), `--color-highlight-menu`.
- Separators group related commands (properties · relations · copy/move · favorite/remind · destructive) [O].
- Destructive item at the **bottom**, separated, with shortcut ("Delete · Ctrl Delete") [O].
- Submenus open on hover/→, include a **filter input as first row** ("Set priority to…") and **numeric quick keys** (0–4) [O]. Submenu uses `--shadow-floating`.
- Keyboard: ↑/↓ move, → / Enter opens submenu, ← / Esc closes **one level at a time** (verified) [O], typing filters [O].

### 7.10 Command palette [O]
- 720px wide, top offset ≈112–120px, radius 12, `--color-surface-floating`, 1px popover border, `--shadow-floating`. **No dim backdrop** (both Linear and ChatGPT) [O].
- Height shrinks to fit results (max ≈450px, then scrolls) [O].
- Input row: placeholder "Type a command or search…", right-aligned hint for an alternate mode ("Ask Linear · Tab") [O] — [R] use for "Ask AI" if the product has AI.
- Groups: label 12/500 tertiary, padding 8 12.
- Rows: 46px pitch, highlight inset 2px, radius 8, `--color-highlight-menu`; leading icon, label 13/450, trailing shortcut (`C`, `V`, `N then P`).
- Contextual: rows are scoped to the current page/selection first [I].
- Nested commands push a new prompt into the same box ("Change interface theme to…") with numeric shortcuts 1–n and a ✓ on the current value [O].
- Empty result: "No results found" + secondary action ("Go to advanced search") [O].
- First row is pre-highlighted; Enter runs it; Esc closes [O].

### 7.11 Dialog (modal) [O]
- 750px wide (create flows), top ≈120px (not vertically centered), radius 21 (Linear) → [R] 16px; `--shadow-floating`; 1px popover border; dimmed background [V].
- Header: context breadcrumb chip ("Team › New issue") left; expand-to-fullscreen + close (28px ghost icons) right.
- Body: borderless title (18/600) and description (15/450) fields — no labels, placeholders only.
- Property chips row (24px pills).
- Footer: attachment icon left; "Create more" switch + primary button right.
- Esc closes (nothing saved) [O]; Ctrl+Enter submits [O shortcut catalogue].
[R] Prefer side sheets or inline editing over dialogs for non-creation flows.

### 7.12 Side sheet [O]
360px wide, 12px inset from viewport edges, radius 12, `--shadow-menu`, 25% black scrim, title 15/600 + close icon, search input auto-focused. Esc closes.

### 7.13 Tooltip [O]
- Linear: light tooltip — `--color-surface-raised`, 1px popover border, radius 8, padding 5px 8px, 12/450 text-secondary, `--shadow-panel`; inline `kbd` (18×19, radius 4, 1px faint border, 12px). Appears below the trigger, ≤1s delay [O, exact delay U].
- ChatGPT: dark inverse pill — bg `#0d0d0d`, white 14/600, radius 16, padding 5px 12px [O].
- [R] Use Linear's light tooltip (dark tooltip in dark theme = raised surface). Content = label + shortcut. Delay 500ms open, 0ms between adjacent triggers.

### 7.14 Keyboard hint (`kbd`) [O]
min 18×19px, padding 2–4px, radius 3–4px, 1px border `lch(97.3)` / faint, 12px text-tertiary. Chords rendered as `G` `then` `I`; modifiers as `Ctrl` `⇧` `Alt` (platform-specific: `⌘` on macOS [R]).

### 7.15 Tables
[U] Linear's spreadsheet-like table views were not inspected. [R] Implement tables as list rows (44px → 36px compact), sticky 32px header with 12/500 tertiary labels, no vertical gridlines, 1px `--color-border-subtle` horizontal lines only when > 6 columns, right-align numbers with tabular figures.

### 7.16 Toasts / notifications
[U] Not triggered. Linear shortcuts confirm toasts exist with actions ("Open link from last toast · Ctrl Alt O", "Dismiss all toasts · Ctrl Alt X") [O]. [R] Bottom-right (LTR) / bottom-left (RTL), 360px max, raised surface + `--shadow-menu`, 13px text, optional single action + undo, auto-dismiss 5s (pause on hover), stack max 3.

### 7.17 Empty, loading, error, success states
| State | Observed | Rule |
|---|---|---|
| Empty list | "No notifications" — single line 13/500 tertiary, centered [O] | One line; optional single CTA; no illustrations in narrow panes [R] |
| Empty detail pane | 1px-stroke line illustration (~100px) + caption "No notification selected" [O] | Outline icon-style art only, neutral color [R] |
| Empty page section | Placeholder text as affordance ("Add a description…", "Add documents and links…") [O] | Make the empty state *the input* |
| App loading | Panel frame + centered faded logo mark, no spinners [O] | Render shell immediately; skeletons inside panel [R] |
| Inline loading | [U] | 12px spinner in place of icon; keep layout stable [R] |
| Error | `--loading-error-*` tokens exist (muted text `#5b5b5d`, secondary button `#fefeff` with 1px `#00000016` border) [O] | Calm inline error: title 13/500, description 12/450, secondary "Retry" button; red only for the icon [R] |
| Success | [U] | Prefer optimistic UI + toast with Undo over success screens [R] |
| Search no results | "No results found" + alternative action [O] | Always offer a next step |

---

## 8. Navigation, keyboard, command palette & contextual actions

### 8.1 Navigation model [O/I]
- Persistent left sidebar: personal (Inbox, My items, Drafts…) → workspace sections → favorites → teams (expandable sub-nav) → secondary "Try"/onboarding links.
- Breadcrumb header inside the panel; detail pages show list position "3 / 6" with ↑/↓ pager [O].
- [R] Map the product's own IA onto: **Personal · Workspace · Favorites · Groups (teams/projects/branches) · Utility** — keep the product's names.

### 8.2 Shortcut system (observed catalogue, abridged) [O]
| Category | Shortcuts |
|---|---|
| Global | `Ctrl K` command menu · `/` search · `?` help · `Ctrl /` shortcut sheet · `Esc` back/close · `Ctrl Enter` save/submit · `[` / `]` toggle left/right sidebar |
| Go-to chords | `G` then `I` inbox, `M` my issues, `S` settings, `D` drafts, `P` projects, `A` active, `B` backlog, `E` all … |
| Open chords | `O` then `I` issue, `P` project, `V` view, `U` user, `F` favorite … |
| Create | `C` new item · `V` new in full screen · `Alt C` from template · `N then P` new project |
| Item properties | `S` status · `P` priority · `A` assign · `I` assign to me · `L` labels · `⇧D` due date · `⇧R` rename · `Alt F` favorite · `⇧H` remind · `Ctrl Delete` delete |
| Copy | `Ctrl .` ID · `Ctrl ⇧ ,` URL · `Ctrl ⇧ '` title · `Ctrl Alt C` as Markdown |
| List/board | `J`/`K` or ↑/↓ move · `Space` peek · `Enter` open · `X` select · `Ctrl A` select all · `Ctrl B` toggle list/board · `F` add filter · `⇧V` display options · `T` collapse row |
| Editor | Markdown shortcuts (`#`+Space etc.), `Ctrl B/I/U/E/K`, `Ctrl ⇧ 7/8/9` lists |

### 8.3 Rules for implementations [R]
1. **Every visible action has a shortcut or palette entry; every shortcut is visible** in at least a tooltip, a menu item, or the shortcut sheet.
2. Single-key shortcuts only fire when focus is not in an editable field; chords (`G then X`) time out after ~1s.
3. Use the **same property menus** for: row context menu, chip click, palette nested command, and single-key shortcut — one component, four entry points.
4. Context menu on right-click **and** on a "…" button for touch/accessibility.
5. Multi-select (X / ⇧-click) turns the context menu and palette into **bulk actions**.
6. Esc unwinds one layer: submenu → menu → dialog → selection → detail → list.
7. Do not override browser/OS critical shortcuts (Ctrl W/T/L, ⌘Q).
8. On Arabic/RTL keyboards, bind by `event.code` (physical key) for letter shortcuts so `C`, `G`, `J/K` still work [R].

---

## 9. ChatGPT patterns — adopt vs keep secondary

### 9.1 Observed ChatGPT metrics [O]
| Element | Value |
|---|---|
| Font | system stack (`-apple-system-body, ui-sans-serif, system-ui, "Segoe UI", Helvetica…`), body 16/24, page bg `#fcfcfc` |
| Sidebar | ~340px, items 35px, radius 8, padding 6 10, 14/400; active bg `rgb(0 0 0/.05)`; section labels 14/500 `#8f8f8f`; hover reveals "…" and pin icons |
| Thread width | 768px (`48rem`) |
| Composer (idle) | 768×52, radius 26 (pill), white, shadow `0 0 0 1px rgb(0 0 0/.04), 0 2px 8px rgb(0 0 0/.04), 0 4px 80px 8px rgb(0 0 0/.024)` |
| Composer (multiline) | grows to 102px, radius 28; text row above, tool row below |
| Composer controls | leading "+" (attach/tools menu); trailing mode toggle, mic, 36px circular primary button (voice when empty → **Send** when text present), blue `rgb(58 131 247)` |
| Empty state | greeting 24/400 centered above composer (personalized) |
| User message | right-aligned bubble, max-width 70%, radius 22, padding 10 16, bg `#e8f3fe`, text `#0c274a` |
| Assistant message | no bubble, full column width, 16/26; h2 24/32 600; h3 20/28 600; lists `padding-left:26px`, `li` 6px; `hr` 1px `rgb(0 0 0/.15)` margin 28px; blockquote left rule + 24px padding; inline code .93em mono, bg `rgb(243 243 243/.82)`, radius ~3.7px |
| Message actions | row below the answer: copy, feedback, share, read aloud, regenerate, more — 32px icon buttons, radius 8, icon 20px `#8f8f8f`, hover bg `rgb(0 0 0/.05)`; dark pill tooltip ("Copy response") |
| Timestamp | centered separator, 14/500 `#8f8f8f` ("Sat, Jun 20 at 7:37 PM") |
| Scroll-to-latest | 32px circle, 1px `rgb(0 0 0/.1)` border, floating above composer |
| Disclaimer | 12px `#8f8f8f` under composer |
| "+" menu | expands upward over the thread, same width as composer, radius 20, 1px `rgb(0 0 0/.1)` border, padding 8; rows 36px radius 12 with label + inline gray description |
| Search dialog | 720px, radius 16, 1px border, shadow `0 16px 32px -8px rgb(0 0 0/.19)`, no dim; rows 48px radius 12 |
| Inline citation | small gray pill (`#f3f3f3`, radius 12) after the sentence |
| RTL | paragraphs use `dir="auto"` → Arabic paragraphs render RTL/right-aligned while English lists stay LTR inside the same message |

### 9.2 Linear's AI surface (the bridge) [O]
- Composer: 712px, radius 10, padding 12, raised white, `--shadow-panel`; placeholder 15/450; footer with a "Skills"-style selector (left) and attach + 24px accent send (right).
- Recent conversations under the empty composer: 32px rows, radius 10, title 13/450, relative time right (13/450 tertiary), **8px accent unread dot**.
- User message: right-aligned, bg `#f5f5f5`, **radius 8**, padding 8 12, 15/450.
- Assistant: plain 15/450 lh 24, no avatar.
- **"Worked for N seconds ▸"** disclosure (13/500 tertiary) → expands a reasoning trace with a 1px left rule, muted 12–13px steps, and tool-step labels ("Updated issues").
- Inline **entity chips** for referenced objects (status glyph + ID + title; radius 4, bg `#efefef`, 1px faint border, 15px) with **hover cards** (300px, properties row).
- Results of actions render as an **embedded mini-list** (rows 32px) inside the answer.
- Feedback row: 24px ghost icons (👍 👎 copy) under the last answer.

### 9.3 Adopt (the 20%) [R]
1. **Centered reading column** 720–800px for any conversational or long-form view; composer shares the column width.
2. **Bubble-less assistant, compact user bubble** (Linear style: neutral `#f5f5f5`, radius 8 — not ChatGPT's large blue pill, unless brand demands).
3. **Composer that grows** from one line to max ~40% viewport height, then scrolls internally; Enter sends, ⇧Enter newline (configurable — Linear exposes "Send comments on… Enter" [O]).
4. **Primary button morphs by state:** disabled (empty) → Send (text) → **Stop** (generating) → Send. [U] Stop state not observed; implement anyway.
5. **Hover/last-message action row**: copy, retry/regenerate, feedback; icons only + tooltips.
6. **Reasoning/tool disclosure** collapsed by default with duration ("Worked for 4s").
7. **Entity chips + hover cards** whenever AI references app objects — this is the most "Linear" AI pattern and should be preferred over raw links.
8. **Scroll-to-latest button** appears only when the user has scrolled up > 1 screen.
9. **Attachment/tools menu from "+"**, rows with inline descriptions (progressive disclosure of AI capabilities).
10. **dir="auto" per paragraph** for mixed Arabic/English content.
11. Recent conversations listed under the empty composer with unread dots.

### 9.4 Keep secondary / avoid [R]
- ChatGPT's 16px+ type and 26px line-height in dense app chrome (fine inside the chat column only).
- Large pill radii (26–28px composer, 20px menus, 22px bubbles) — clashes with Linear's 8–12px system. Use 10–12px.
- Inverse black tooltips (use Linear's light tooltip).
- Personalized marketing-style greeting headlines in work tools; prefer a quiet placeholder.
- Saturated blue send button — use the product's accent.
- Footer disclaimer text on every screen — show once in the AI panel, 12px tertiary.

### 9.5 AI interaction states (spec) [R unless noted]
| State | UI |
|---|---|
| Idle/empty | Placeholder "Ask …"; send disabled; recent threads below [O pattern] |
| Composing | Send enabled (accent); attachments as 24px chips above text |
| Submitted / thinking | User bubble appears instantly; below it a muted "Thinking…" line with shimmer (opacity 0.5↔1, 1.2s) |
| Tool running | Disclosure line "Searching issues…" with a 12px spinner; expands to steps |
| Streaming | Text appends in place; no layout jumps; auto-scroll only if user is at bottom; send→Stop (square icon) |
| Complete | Disclosure collapses to "Worked for Ns ▸" [O]; action row appears [O] |
| Stopped | Keep partial text + "Stopped" meta in tertiary; Retry action |
| Error | Inline 13px message under the turn, red icon only, "Retry" secondary button; keep user text in composer |
| Action applied | Embedded mini-list of affected items + Undo in toast [O pattern + R] |
| Rate-limited/offline | Composer disabled with one-line reason above it |

---

## 10. Light & dark theme guidance

1. Build both themes from **three inputs**: base neutral (hue/chroma), accent (brand primary), contrast level — as Linear documents [D]. Use LCH/OKLCH in code; hex fallbacks are in §4.
2. **Light:** surfaces go *lighter* as they rise (app `#efeff0` → panel `#f9f9fa` → raised `#fff`); shadows are extremely soft (≤10% alpha).
3. **Dark:** surfaces go *lighter* as they rise (`#09090a` → `#121213` → `#1a1a1b` → `#212122`); depth comes from **1px light rings (≈5% white)**, not shadows [O].
4. Text in dark is pure white for primary, `#e3e4e6` secondary, `#959597` tertiary [O]. Do not invert the light gray ladder mechanically.
5. Accent stays the same hue in both themes [O]; [R] raise lightness ~6–8 L in dark if contrast against `#121213` < 4.5:1 for text use.
6. Semantic colors: use base hue for glyphs in both themes; use subtle backgrounds only in light; in dark use 12–16% alpha of the base [R].
7. Whether the theme switch animates was not checked [U]; [R] switch instantly (no color transition) and respect `prefers-color-scheme` when set to System [O option].
8. Never put a drop shadow on dark surfaces without a ring; never use pure black `#000` panels.

---

## 11. Accessibility & responsive behavior

### 11.1 Contrast (computed from measured colors)
| Pair | Ratio | Verdict |
|---|---|---|
| text-primary `#1b1b1b` on panel `#f9f9fa` | 16.4:1 | AAA |
| text-secondary `#2f2f31` on panel | 12.7:1 | AAA |
| text-tertiary `#5c5c5e` on panel | 6.3:1 | AA |
| text-tertiary on app-bg `#efeff0` | 5.8:1 | AA |
| text-quaternary `#9c9d9f` on panel | 2.6:1 | **Fails** — placeholders/disabled only |
| white on accent `#6d78d5` (Linear primary button, 12px) | 3.96:1 | **Fails AA for small text** |
| dark text-tertiary `#959597` on `#121213` | 6.3:1 | AA |
| dark text-quaternary `#565759` on `#121213` | 2.6:1 | **Fails** — decorative only |
| ChatGPT meta `#8f8f8f` on `#fcfcfc` | 3.2:1 | Fails AA for 12–14px |
| ChatGPT user bubble text `#0c274a` on `#e8f3fe` | 13.3:1 | AAA |
| control border `#d8d8d8` on panel | 1.35:1 | Below 3:1 non-text — **inputs need focus/hover reinforcement or darker border** |

**Requirements [R]**
- Body/meta text ≥ 4.5:1; never use quaternary for information.
- Primary button: darken accent until on-accent text ≥ 4.5:1 (e.g. indigo ≈ `#5a64c8` or darker), or use 13px/600 and accept AA-large only if the product already does.
- Form inputs: border ≥ 3:1 against background **or** a visible label + raised fill; focus ring ≥ 3:1.
- Focus visible on every interactive element (1px accent outline [O]; use 2px where 1px is not 3:1 against both neighbors).
- All icon-only buttons have `aria-label` and a tooltip.
- Menus use `role="menu"/"menuitem"`, palette uses `role="combobox"` + `listbox/option` with `aria-activedescendant` — Linear's palette uses `role="option"`, `aria-selected`, `data-focused` [O].
- Respect `prefers-reduced-motion` (disable translate/scale; keep ≤100ms opacity) [O exists].
- Gate hover-only reveals behind `(any-hover: hover)`; on touch, always show the "…" action button [O media pattern].
- Hit targets: 28px visual controls need ≥ 24×24 target (WCAG 2.2 AA min) — met; on touch layouts raise to 40–44px [R].
- Font-size setting: Linear offers app-wide "Font size" [O]; [R] implement with `rem` + a root size switch (14/15/16px).
- RTL: use logical properties (`margin-inline-start`, `inset-inline-end`), mirror chevrons/arrows, keep numbers/IDs LTR with `<bdi>`/`dir="ltr"`, and use `dir="auto"` on user-generated text [R; ChatGPT pattern O].

### 11.2 Responsive
Observed: Linear CSS contains breakpoints at **640px, 880px, 1023px** [O]; behavior at those widths was **not observed** [U].

Recommended [R]:
| Width | Behavior |
|---|---|
| ≥ 1280 | Full shell: sidebar 244 + inset panel; detail pages show properties rail |
| 1024–1279 | Properties rail collapses into a toggle (`]`) side sheet; board columns scroll horizontally |
| 881–1023 | Sidebar becomes overlay (opened by icon or `[`), panel inset 0–8px |
| 641–880 | Single column; list rows hide chips (keep status, title, avatar); dialogs become 100% − 32px wide |
| ≤ 640 | Mobile: no inset panel (radius 0), top bar 48px with menu + title + primary action; rows 48px; dialogs → bottom sheets; context menu → action sheet; palette full-screen; chat composer pinned to bottom with safe-area padding |

---

## 12. Implementation guidance (React + TypeScript; adaptable)

### 12.1 Stack recommendations [R]
- **Styling:** CSS variables from §4.7 as the single source of truth; consume via Tailwind (`theme.extend.colors = { panel: 'var(--color-panel)', … }`) or CSS Modules/vanilla-extract. Do not hard-code hex in components.
- **Primitives:** Radix UI (DropdownMenu, ContextMenu, Dialog, Tooltip, Popover, Switch) or React Aria — both give correct roles/keyboard handling.
- **Command palette:** `cmdk` (filter, groups, nested pages) styled per §7.10.
- **Shortcuts:** a central registry (`tinykeys` or custom) with scopes; the same registry renders tooltips, menu hints and the shortcut sheet.
- **Lists:** virtualization (`@tanstack/react-virtual`) for > 200 rows; fixed 44px row height.
- **Font:** `@fontsource-variable/inter`; set `font-feature-settings: "cv11", "ss01"` only if brand-approved [R].
- **Icons:** one 16px outline set at 1.5px stroke (Lucide/Phosphor) rendered at 14px in controls; never mix sets.
- If the project is not React, keep tokens + state matrices; map components to the existing framework's primitives.

### 12.2 File structure
```
src/design-system/
  tokens.css            // §4.7
  theme.ts              // light/dark/system switch, data-theme on <html>
  shortcuts/registry.ts // id, keys, scope, label, handler
  components/
    AppShell.tsx Sidebar.tsx NavItem.tsx PanelHeader.tsx ViewBar.tsx
    Button.tsx IconButton.tsx Kbd.tsx Tooltip.tsx
    Menu.tsx (Dropdown/Context share items) CommandPalette.tsx
    Dialog.tsx SideSheet.tsx Chip.tsx Input.tsx Select.tsx Switch.tsx
    ListRow.tsx GroupHeader.tsx Card.tsx EmptyState.tsx Toast.tsx
    ai/ Composer.tsx Message.tsx ReasoningDisclosure.tsx EntityChip.tsx MessageActions.tsx
```

### 12.3 Reference implementations

```tsx
// IconButton.tsx
type IconButtonProps = React.ButtonHTMLAttributes<HTMLButtonElement> & {
  label: string; shortcut?: string[]; size?: 24 | 28; icon: React.ReactNode;
};
export function IconButton({ label, shortcut, size = 28, icon, ...rest }: IconButtonProps) {
  return (
    <Tooltip content={<>{label}{shortcut && <Kbd keys={shortcut} />}</>}>
      <button aria-label={label} className="icon-btn" data-size={size} {...rest}>{icon}</button>
    </Tooltip>
  );
}
```
```css
.icon-btn{inline-size:28px;block-size:28px;display:inline-grid;place-items:center;border-radius:var(--radius-pill);
  color:var(--color-text-secondary);background:transparent;border:1px solid transparent;
  transition:border .15s,background-color .15s,color .15s,opacity .15s}
.icon-btn[data-size="24"]{inline-size:24px;block-size:24px}
.icon-btn svg{inline-size:14px;block-size:14px}
@media (any-hover:hover) and (any-pointer:fine){.icon-btn:hover{background:var(--color-btn-ghost-hover)}}
.icon-btn:focus-visible{outline:1px solid var(--color-focus-ring);outline-offset:1px}
.icon-btn:disabled{color:var(--color-text-quaternary);pointer-events:none}
```
```css
/* App shell */
.app{display:grid;grid-template-columns:var(--sidebar-width) 1fr;height:100dvh;background:var(--color-app-bg)}
.app[data-sidebar="hidden"]{grid-template-columns:0 1fr}
.panel{margin:var(--panel-inset) var(--panel-inset) var(--panel-inset) 0;background:var(--color-panel);
  border:1px solid var(--color-border-subtle);border-radius:var(--radius-xl);box-shadow:var(--shadow-panel);
  display:flex;flex-direction:column;min-width:0;overflow:hidden}
.app[data-sidebar="hidden"] .panel{margin-inline-start:var(--panel-inset)}
.panel-header{block-size:44px;display:flex;align-items:center;gap:8px;padding-inline:12px 8px;
  border-bottom:1px solid var(--color-border-subtle);font:500 13px/1 var(--font-sans);color:var(--color-text-secondary)}
.view-bar{block-size:43px;display:flex;align-items:center;gap:8px;padding-inline:8px}
.panel-body{flex:1;overflow:auto}
```
```css
/* List row */
.row{position:relative;block-size:var(--size-row);display:flex;align-items:center;gap:8px;padding-inline:8px 12px;
  margin-inline:8px;border-radius:var(--radius-md);font:500 13px/1 var(--font-sans);color:var(--color-text-primary)}
.row::before{content:"";position:absolute;inset:0;border-radius:inherit;background:transparent;z-index:-1}
@media (any-hover:hover){.row:hover::before{background:var(--color-hover)}.row:hover .row-check{opacity:1}}
.row[data-focused="true"]::before{background:var(--color-hover);box-shadow:inset 2px 0 0 var(--color-accent)}
.row[aria-selected="true"]::before{background:var(--color-selection-active)}
.row .id,.row .date{font-weight:450;color:var(--color-text-tertiary);font-variant-numeric:tabular-nums}
.row .date{font-size:12px}
.row-check{opacity:0;transition:opacity .15s}
.group-header{block-size:36px;margin:0 8px;padding-inline:8px;border-radius:var(--radius-md);background:var(--color-hover);
  display:flex;align-items:center;gap:8px;font:500 13px/1 var(--font-sans)}
```
```css
/* Floating surfaces */
.menu{min-inline-size:180px;padding:4px;border-radius:var(--radius-xl);background:var(--color-surface-floating);
  border:1px solid var(--color-border-popover);box-shadow:var(--shadow-menu)}
.menu-item{position:relative;block-size:32px;display:flex;align-items:center;gap:8px;padding:0 18px 0 14px;
  font:450 13px/1 var(--font-sans);color:var(--color-text-primary)}
.menu-item[data-highlighted]::before{content:"";position:absolute;inset:2px 0;border-radius:var(--radius-md);
  background:var(--color-highlight-menu);z-index:-1}
.menu-item .kbd-hint{margin-inline-start:auto;font:500 12px/1 var(--font-sans);color:var(--color-text-tertiary)}
.palette{position:fixed;inset-block-start:min(15vh,120px);inset-inline-start:50%;translate:-50% 0;inline-size:min(720px,calc(100vw - 32px));
  max-block-size:450px;border-radius:var(--radius-xl);background:var(--color-surface-floating);
  border:1px solid var(--color-border-popover);box-shadow:var(--shadow-floating);overflow:hidden}
.tooltip{padding:5px 8px;border-radius:var(--radius-md);background:var(--color-surface-raised);
  border:1px solid var(--color-border-popover);box-shadow:var(--shadow-panel);font:450 12px/18px var(--font-sans);color:var(--color-text-secondary)}
.kbd{display:inline-grid;place-items:center;min-inline-size:18px;block-size:19px;padding:0 4px;border-radius:4px;
  border:1px solid var(--color-border);font:450 12px/1 var(--font-sans);color:var(--color-text-tertiary)}
```
```tsx
// Shortcut registry (single source for tooltips, menus, sheet)
export type Shortcut = { id: string; keys: string[]; chord?: boolean; scope: 'global'|'list'|'detail'|'editor';
  label: string; run: () => void; when?: () => boolean };
// Ignore when target is input/textarea/[contenteditable]; match on event.code for RTL keyboards.
```
```tsx
// AI Composer behavior
// - textarea auto-grows to max 40vh; Enter = send, Shift+Enter = newline (respect user setting)
// - button state: 'disabled' | 'send' | 'stop'; aria-label changes accordingly
// - while streaming: Esc or Stop aborts (AbortController); keep partial text
// - auto-scroll only if distance from bottom < 80px; else show ScrollToLatest button
```

### 12.4 Do / Don't [R]
| Do | Don't |
|---|---|
| Neutral surfaces, 1 accent | Gradients, glassmorphism, colored panels |
| 8–12px radii (pill for small controls) | 16–24px rounded cards everywhere |
| Hairlines + near-invisible shadows | `shadow-lg`/`shadow-xl` on cards |
| 13px UI text, weight for hierarchy | 18–20px body text in app chrome, 36px+ headings |
| Inline editing & borderless titles | Forms with a label box for every field |
| Hover-reveal secondary actions | Rows with 5 always-visible icon buttons |
| Tinted group headers, no row dividers | Zebra stripes + gridlines |
| One "Create" primary per region | Multiple competing colored buttons |
| Empty state = the input / one line | Big illustrations + paragraphs in work views |
| Command palette + shortcuts everywhere | Actions only discoverable via mouse |
| Generic KPI cards only when data warrants | Default "dashboard template" with 4 stat cards + chart |

---

## 13. Evaluation checklist (acceptance criteria)

Mark each ✅/❌ against the implemented product.

**Tokens & theme**
- [ ] All colors come from CSS variables; zero hard-coded hex in components (grep check).
- [ ] Light neutrals within ±2% L of §4.1; dark within ±2% L of §4.2.
- [ ] Brand primary replaces accent; on-accent text ≥ 4.5:1.
- [ ] Light, Dark, System themes; no flash of wrong theme on load.

**Shell & layout**
- [ ] Sidebar 240–248px, same color as window; main panel inset 8px, radius 12, 1px border.
- [ ] Header 44px; view bar ≤ 44px; content scrolls inside the panel only.
- [ ] `[` toggles sidebar; panel keeps inset.
- [ ] Reading columns 640–800px; palette 720px; side sheet 360px.

**Typography**
- [ ] ≤ 5 font sizes across app chrome (12/13/15/18/24).
- [ ] No heading > 24px inside the app.
- [ ] Metadata uses tertiary color; quaternary used only for placeholder/disabled.

**Components**
- [ ] Controls: 24/28px heights only (32 menu rows, 44 list rows, 36 group headers).
- [ ] Every component implements the state matrix (default/hover/focus-visible/selected/disabled/loading).
- [ ] Focus ring visible on 100% of interactive elements (keyboard tab-through test).
- [ ] Hover styles gated by `(any-hover: hover)`; touch has visible "…" actions.
- [ ] Only 3 shadow levels used (panel/raised/floating + menu variant).

**Keyboard & actions**
- [ ] Ctrl/⌘K palette with groups, shortcuts shown, arrow navigation, nested commands, empty state with next step.
- [ ] `?` or Ctrl+/ opens a searchable shortcut sheet generated from the registry.
- [ ] Right-click context menu on rows/cards, mirrors the "…" button, shows shortcuts.
- [ ] Esc closes one layer at a time.
- [ ] Tooltips on icon buttons show label + shortcut.
- [ ] J/K (or ↑/↓) moves focus in lists; Enter opens; X selects; bulk actions available.

**AI / conversation (if applicable)**
- [ ] Single centered column ≤ 800px; composer same width; composer grows; Enter/⇧Enter.
- [ ] Send ↔ Stop morph; streaming does not jump layout; scroll-to-latest appears when scrolled up.
- [ ] Assistant prose without bubble; user bubble neutral, radius ≤ 12.
- [ ] Reasoning/tool steps collapsed with duration label.
- [ ] App objects referenced by AI render as entity chips with hover cards.
- [ ] Copy / retry / feedback actions on the latest answer.
- [ ] Mixed RTL/LTR text renders correctly (`dir="auto"`).

**Accessibility & responsive**
- [ ] Text contrast ≥ 4.5:1 (automated axe run passes).
- [ ] `prefers-reduced-motion` honored.
- [ ] Layout verified at 1440, 1024, 768, 390px.
- [ ] RTL mirror verified (if product supports Arabic/Hebrew).

**Anti-patterns (must all be absent)**
- [ ] No decorative gradients, no glassmorphism, no colored card backgrounds.
- [ ] No card radius > 12px (except pills/composer), no `shadow-lg` on static content.
- [ ] No Linear/ChatGPT logos, names, illustrations or product-specific terms copied.

---

## 14. Open questions & areas needing further inspection

1. **Responsive behavior** at 640/880/1023px breakpoints (observed in CSS, not exercised). Inspect by resizing a dedicated window.
2. **ChatGPT streaming states**: stop button, cursor/caret, partial markdown rendering, auto-scroll thresholds. Requires a longer prompt and screen recording.
3. **ChatGPT dark theme** tokens.
4. **Linear motion specifics**: palette/menu/dialog enter-exit curves and durations (runtime-generated classes; needs a performance recording or slowed animations).
5. **Toasts, error banners, validation errors, offline state** in Linear (not triggered to avoid modifying data).
6. **Drag-and-drop** (board cards, sidebar reorder): drag ghost, drop indicators.
7. **Table/spreadsheet view**, **timeline**, and **date picker** components.
8. **Selected pill-tab fill in light theme** (only dark measured: `#29292b`).
9. **Dark-theme hover colors** for nav and ghost buttons (marked [R] in tokens).
10. **Tooltip open delay** exact value.
11. **Mobile/touch adaptations** (Linear mobile web/app, ChatGPT mobile).
12. **High-contrast theme** generation (Linear documents a contrast variable [D]; output values not inspected).
13. **Backdrop treatment** behind Linear's create dialog (dimmed visually; element not identified).
14. Whether the product's **brand primary** will pass 4.5:1 with white text — must be decided per adoption.

---

### Sources
- Live inspection: linear.app (workspace "Ahmedgaid01") and chatgpt.com, 2026-10-19.
- Linear, "How we redesigned the Linear UI": https://linear.app/now/how-we-redesigned-the-linear-ui
- Linear changelog, "New Linear UI" (2024-03-20): https://linear.app/changelog/2024-03-20-new-linear-ui
