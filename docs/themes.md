# Themes — multi-theme system + `/theme` command

Live progress log. Tick each phase: `[ ]` todo · `[-]` in progress · `[x]` done.

## Context

pito had one hardcoded theme (`<html data-theme="tokyo-night">` + a hand-written
`[data-theme="tokyo-night"]` block). This adds a real multi-theme system: 18
light/dark themes, a `/theme` command (preview sidebar + direct `/theme <name>`),
global persistence, and a data-driven engine (one Ruby file per theme → loader →
rake-generated CSS) so adding a theme is a one-file change. **pito brand blue
(`--brand-pito` #5170ff) is identical on every theme**; only the other tokens
change.

## Decisions

- One **Ruby file per theme** (`app/services/pito/themes/definitions/*.rb`) →
  registry/loader → **`rake pito:themes:export`** writes a committed
  `app/assets/tailwind/themes.css` imported by `application.css`.
- Each file gives base `bg`, `fg`, the 7 accents; loader **auto-derives**
  surface/elevated, fg-dim/faded, borders via `mix()`; per-theme **overrides** ok.
- Existing theme = **Tokyo Night** (kept as the **default**); **Dracula** added.
- **Light-theme audit**: route hardcoded colors through tokens; pito blue constant.
- Global via **`AppSetting`** (`#pito-settings` + broadcast pattern).
- Branch `themes`; PR at the end, **do not merge until validated**. Sonnet-first
  (escalate to Opus). Specs for Rails **and** JS (Vitest).

## Token contract (every theme)

`--bg-root/-surface/-elevated`, `--border-default/-faded`, `--fg-default/-dim/-faded`,
`--accent-{purple,blue,cyan,green,yellow,orange,red}`, constant `--brand-pito`.

## The 18 themes

**Dark:** tokyo-night _(default)_, dracula, one-dark, gruvbox-dark, nord,
github-dark, catppuccin-mocha, ayu-dark, ayu-mirage, solarized-dark,
tomorrow-night.
**Light:** one-light, gruvbox-light, github-light, catppuccin-latte, ayu-light,
solarized-light, tomorrow.

Palettes from terminalcolors.com / canonical sources; ANSI → accents + base
bg/fg, rest derived.

## Architecture

- `Pito::Themes::Mix` (port `mix()` from `app/services/pito/theme.rb`),
  `Pito::Themes::Definition` (Data: slug/label/mode + resolved tokens),
  `Pito::Themes::Registry` (loader: `all`/`find`/`names`/`grouped`/`default`),
  `Pito::Themes::CssGenerator` (ERB → `:root` + `[data-theme]` blocks).
- Persistence: `AppSetting.theme` (default `tokyo-night`); `<html data-theme>` +
  `#pito-settings data-theme`; `PATCH /settings/theme`.
- `/theme` handler: `enum :target, source: :theme_names` (dynamic vocab from the
  registry + `list`); no-arg/`list` → sidebar; valid slug → apply; `--help`.
- Sidebar `Pito::Sidebar::Themes::Component` grouped Dark/Light, current marker,
  witty hint; turbo_stream into `#pito-sidebar`.
- `theme_nav_controller.js`: ↑/↓ live-preview (`documentElement.dataset.theme`),
  Enter apply+PATCH, Esc/disconnect revert.

## Phases

- [ ] **P0 — Setup:** branch `themes` + this `docs/themes.md` + PR.
- [ ] **P1 — Engine core:** `Mix`/`Definition`/`Registry` + tokyo-night + dracula + specs.
- [ ] **P2 — CSS generation:** `CssGenerator` + ERB + `pito:themes:export` rake +
      wire `themes.css` into `application.css` (drop inline block) + specs.
- [ ] **P3 — All theme definitions:** the remaining 16 palettes + regenerate +
      completeness/brand-pito-constant spec.
- [ ] **P4 — Persistence:** `AppSetting.theme` + dynamic `data-theme` +
      `#pito-settings` + `PATCH /settings/theme` + specs.
- [ ] **P5 — `/theme` command:** handler + dynamic `theme_names` vocab + grammar +
      `--help` + apply + autocomplete + `/help`/palette listing + i18n + specs.
- [ ] **P6 — Theme sidebar:** grouped Dark/Light component + row + current marker +
      witty hint + list turbo_stream + specs.
- [ ] **P7 — Preview/apply JS:** `theme_nav_controller.js` + Vitest spec.
- [ ] **P8 — Light-theme audit:** route hardcoded colors through tokens; pito blue
      constant; specs where hooks change.
- [ ] **P9 — Finalize:** full `rspec` + `npm test` + `rubocop` green; PR ready;
      **do not merge** — await validation.

## Per-phase Definition of Done

Doc-blocks (contract on base, specifics on extenders); new + edge-case specs
(Rails + JS where applicable); `bundle exec rspec` + `npm test` + `bin/rubocop` +
`node --check` green; commit + push; PR CI (`rails`/`js`/`prettier`) green; tick
the phase here. Run `prettier --write` on this file before pushing.

## Verification (smoke)

`/theme` opens the grouped sidebar with the current theme marked; ↑/↓ live-preview;
Enter applies + persists (survives reload, global); Esc reverts; `/theme one-dark`
applies directly; `/theme on…` autocompletes; `/theme --help` lists themes; every
theme keeps pito blue; light themes readable.
