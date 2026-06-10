# Theme contrast audit (WCAG 2.x)

> Branch `theme-contrast-audit`. Reproduce: `bundle exec rails runner script/theme_contrast_audit.rb`.

## Method

For every registered theme we resolve its tokens (`Pito::Themes::Registry.all`,
including the `Mix`-derived `surface`/`elevated`/`fg_dim`/`fg_faded`) and compute
the **WCAG 2.x contrast ratio** between each *text* token and each *background*
token using relative luminance:

- linearize each sRGB channel, `L = 0.2126R + 0.7152G + 0.0722B`,
- `ratio = (L_light + 0.05) / (L_dark + 0.05)`.

Backgrounds audited: **page** (`bg_root`), **surface** (`bg_surface`), **elevated**
(`bg_elevated`). Text tokens: `fg_default`, `fg_dim`, `fg_faded`, the seven
`accent_*`, and `brand_pito`.

Thresholds: **FAIL** < 3.0 (fails even large/UI text) · **warn** < 4.5 (fails WCAG
AA for normal text) · ok ≥ 4.5. ✅ ≥4.5 · ⚠️ 3.0–4.5 · ❌ <3.0.

## Findings

Real-text failures (excluding the by-design `fg_faded` placeholder), light themes
ranked worst → best:

| theme | real-text FAIL (<3.0) | warn (3.0–4.5) | verdict |
|---|---:|---:|---|
| **ayu-light** | 22 | 5 | worst — nearly every accent + `fg_dim` invisible on page & surface |
| **gruvbox-light** | 17 | 9 | bright accents wash out on the cream bg |
| **catppuccin-latte** | 16 | 9 | accents (yellow/green/orange/cyan) fail; `fg_default` ok |
| **solarized-light** | 14 | 16 | low-contrast by design — even `fg_default` is only 4.13 on page |
| **tomorrow** | 12 | 10 | yellow/orange/cyan fail hard |
| **one-light** | 6 | 17 | mostly marginal warns |
| **github-light** | **0** | 12 | **the model** — uses darkened accents; only `elevated`/brand borderline |

### Structural causes (cross-cutting, not one-off)

1. **Bright accents on near-white.** ayu/catppuccin/gruvbox/tomorrow keep saturated
   accents (e.g. yellow `#f2ae49`→1.87, orange→2.29, cyan→2.22 on ayu page). For text
   use on a light bg these must be **darkened**. `github-light` proves it works (its
   accents are deliberately dark: blue `#0969da`, green `#1a7f37`, yellow `#9a6700`).
2. **`brand_pito` is a hardcoded constant `#5170ff`** (52 total fails/warns across the
   set). It never adapts, so it warns/fails on almost every light theme and several
   dark ones. A single fixed value can't clear AA on both white and near-black — it
   needs to be theme-adaptive (or split into a light/dark brand value).
3. **`fg_dim` derivation is too aggressive for light mode** (47 fails). `fg_dim = mix(fg,
   bg, 0.40)` lands at ~2.6–3.4 on light surfaces (ayu 2.42, gruvbox 2.80 on surface).
   The 0.40 (and `fg_faded` 0.60) blend should be gentler in `:light` mode.
4. **`elevated` is the worst surface for light themes** — `bg_elevated = mix(bg, fg, 0.12)`
   pulls the bg toward mid-tone, shrinking contrast for mid-tone accents. Anything that
   only passes on `page` tends to fail on `elevated`.

### Recommended direction (for when you're back to eyeball)

- Adopt **github-light-style dark accents** for the failing light themes (ayu, catppuccin,
  gruvbox, tomorrow, solarized) — override `accent_*` per theme to AA-passing values on
  `surface` (the tighter of page/surface).
- Make **`brand_pito` theme-aware** (or at least a light-mode variant) so it clears AA.
- Tune the **light-mode `fg_dim`/`fg_faded` blend** (e.g. 0.30/0.45) so dim text stays ≥3:1.
- Target: every *real* text token (everything except `fg_faded`) ≥ **4.5:1 on surface**,
  ≥ **3:1 on elevated**. `fg_faded` ≥ 3:1 on page is a reasonable floor for placeholders.

---

Thresholds: **FAIL** < 3.0:1 (fails even large/UI text) · **warn** < 4.5:1 (fails AA normal text) · ok ≥ 4.5:1.

Text tokens audited: fg_default, fg_dim, fg_faded, accent_purple, accent_blue, accent_cyan, accent_green, accent_yellow, accent_orange, accent_red, brand_pito against page(bg_root)/surface/elevated.

## Headline — real-text failures (excluding the intentionally-faded `fg_faded` placeholder)

| theme | mode | text token | on | ratio | status |
|---|---|---|---|---:|---|
| ayu-light | light | `accent_yellow` (#f2ae49) | elevated (#e7eaed) | 1.59 | **FAIL** |
| ayu-light | light | `accent_yellow` (#f2ae49) | surface (#f3f4f5) | 1.75 | **FAIL** |
| ayu-light | light | `accent_yellow` (#f2ae49) | page (#fcfcfc) | 1.87 | **FAIL** |
| ayu-light | light | `accent_cyan` (#4cbf99) | elevated (#e7eaed) | 1.89 | **FAIL** |
| ayu-light | light | `accent_orange` (#fa8d3e) | elevated (#e7eaed) | 1.94 | **FAIL** |
| ayu-light | light | `accent_green` (#86b300) | elevated (#e7eaed) | 2.06 | **FAIL** |
| ayu-light | light | `accent_cyan` (#4cbf99) | surface (#f3f4f5) | 2.07 | **FAIL** |
| ayu-light | light | `accent_orange` (#fa8d3e) | surface (#f3f4f5) | 2.13 | **FAIL** |
| ayu-light | light | `fg_dim` (#9c9fa2) | elevated (#e7eaed) | 2.20 | **FAIL** |
| ayu-light | light | `accent_cyan` (#4cbf99) | page (#fcfcfc) | 2.22 | **FAIL** |
| ayu-light | light | `accent_green` (#86b300) | surface (#f3f4f5) | 2.25 | **FAIL** |
| ayu-light | light | `accent_orange` (#fa8d3e) | page (#fcfcfc) | 2.29 | **FAIL** |
| ayu-light | light | `accent_red` (#f07171) | elevated (#e7eaed) | 2.38 | **FAIL** |
| ayu-light | light | `accent_blue` (#399ee6) | elevated (#e7eaed) | 2.41 | **FAIL** |
| ayu-light | light | `fg_dim` (#9c9fa2) | surface (#f3f4f5) | 2.42 | **FAIL** |
| ayu-light | light | `accent_green` (#86b300) | page (#fcfcfc) | 2.42 | **FAIL** |
| ayu-light | light | `fg_dim` (#9c9fa2) | page (#fcfcfc) | 2.59 | **FAIL** |
| ayu-light | light | `accent_red` (#f07171) | surface (#f3f4f5) | 2.61 | **FAIL** |
| ayu-light | light | `accent_blue` (#399ee6) | surface (#f3f4f5) | 2.65 | **FAIL** |
| ayu-light | light | `accent_purple` (#a37acc) | elevated (#e7eaed) | 2.80 | **FAIL** |
| ayu-light | light | `accent_red` (#f07171) | page (#fcfcfc) | 2.80 | **FAIL** |
| ayu-light | light | `accent_blue` (#399ee6) | page (#fcfcfc) | 2.84 | **FAIL** |
| ayu-light | light | `accent_purple` (#a37acc) | surface (#f3f4f5) | 3.07 | warn |
| ayu-light | light | `accent_purple` (#a37acc) | page (#fcfcfc) | 3.29 | warn |
| ayu-light | light | `brand_pito` (#5170ff) | elevated (#e7eaed) | 3.40 | warn |
| ayu-light | light | `brand_pito` (#5170ff) | surface (#f3f4f5) | 3.73 | warn |
| ayu-light | light | `brand_pito` (#5170ff) | page (#fcfcfc) | 4.00 | warn |
| catppuccin-latte | light | `accent_yellow` (#df8e1d) | elevated (#bcc0cc) | 1.44 | **FAIL** |
| catppuccin-latte | light | `accent_orange` (#fe640b) | elevated (#bcc0cc) | 1.64 | **FAIL** |
| catppuccin-latte | light | `accent_yellow` (#df8e1d) | surface (#ccd0da) | 1.70 | **FAIL** |
| catppuccin-latte | light | `accent_green` (#40a02b) | elevated (#bcc0cc) | 1.84 | **FAIL** |
| catppuccin-latte | light | `accent_orange` (#fe640b) | surface (#ccd0da) | 1.93 | **FAIL** |
| catppuccin-latte | light | `accent_cyan` (#179299) | elevated (#bcc0cc) | 2.06 | **FAIL** |
| catppuccin-latte | light | `accent_green` (#40a02b) | surface (#ccd0da) | 2.17 | **FAIL** |
| catppuccin-latte | light | `brand_pito` (#5170ff) | elevated (#bcc0cc) | 2.26 | **FAIL** |
| catppuccin-latte | light | `accent_yellow` (#df8e1d) | page (#eff1f5) | 2.31 | **FAIL** |
| catppuccin-latte | light | `accent_cyan` (#179299) | surface (#ccd0da) | 2.43 | **FAIL** |
| catppuccin-latte | light | `accent_orange` (#fe640b) | page (#eff1f5) | 2.64 | **FAIL** |
| catppuccin-latte | light | `brand_pito` (#5170ff) | surface (#ccd0da) | 2.66 | **FAIL** |
| catppuccin-latte | light | `accent_blue` (#1e66f5) | elevated (#bcc0cc) | 2.70 | **FAIL** |
| catppuccin-latte | light | `accent_green` (#40a02b) | page (#eff1f5) | 2.96 | **FAIL** |
| catppuccin-latte | light | `accent_purple` (#8839ef) | elevated (#bcc0cc) | 2.98 | **FAIL** |
| catppuccin-latte | light | `accent_red` (#d20f39) | elevated (#bcc0cc) | 2.99 | **FAIL** |
| catppuccin-latte | light | `accent_blue` (#1e66f5) | surface (#ccd0da) | 3.18 | warn |
| catppuccin-latte | light | `accent_cyan` (#179299) | page (#eff1f5) | 3.31 | warn |
| catppuccin-latte | light | `fg_dim` (#5c5f77) | elevated (#bcc0cc) | 3.44 | warn |
| catppuccin-latte | light | `accent_purple` (#8839ef) | surface (#ccd0da) | 3.51 | warn |
| catppuccin-latte | light | `accent_red` (#d20f39) | surface (#ccd0da) | 3.52 | warn |
| catppuccin-latte | light | `brand_pito` (#5170ff) | page (#eff1f5) | 3.63 | warn |
| catppuccin-latte | light | `fg_dim` (#5c5f77) | surface (#ccd0da) | 4.05 | warn |
| catppuccin-latte | light | `accent_blue` (#1e66f5) | page (#eff1f5) | 4.34 | warn |
| catppuccin-latte | light | `fg_default` (#4c4f69) | elevated (#bcc0cc) | 4.39 | warn |
| github-light | light | `fg_dim` (#7c7f82) | elevated (#eaeef2) | 3.45 | warn |
| github-light | light | `brand_pito` (#5170ff) | elevated (#eaeef2) | 3.52 | warn |
| github-light | light | `fg_dim` (#7c7f82) | surface (#f6f8fa) | 3.78 | warn |
| github-light | light | `brand_pito` (#5170ff) | surface (#f6f8fa) | 3.86 | warn |
| github-light | light | `fg_dim` (#7c7f82) | page (#ffffff) | 4.03 | warn |
| github-light | light | `brand_pito` (#5170ff) | page (#ffffff) | 4.11 | warn |
| github-light | light | `accent_yellow` (#9a6700) | elevated (#eaeef2) | 4.17 | warn |
| github-light | light | `accent_cyan` (#1b7c83) | elevated (#eaeef2) | 4.23 | warn |
| github-light | light | `accent_orange` (#bc4c00) | elevated (#eaeef2) | 4.32 | warn |
| github-light | light | `accent_purple` (#8250df) | elevated (#eaeef2) | 4.33 | warn |
| github-light | light | `accent_green` (#1a7f37) | elevated (#eaeef2) | 4.36 | warn |
| github-light | light | `accent_blue` (#0969da) | elevated (#eaeef2) | 4.45 | warn |
| gruvbox-light | light | `accent_yellow` (#d79921) | elevated (#d5c4a1) | 1.45 | **FAIL** |
| gruvbox-light | light | `accent_green` (#98971a) | elevated (#d5c4a1) | 1.81 | **FAIL** |
| gruvbox-light | light | `accent_yellow` (#d79921) | surface (#ebdbb2) | 1.81 | **FAIL** |
| gruvbox-light | light | `accent_cyan` (#689d6a) | elevated (#d5c4a1) | 1.85 | **FAIL** |
| gruvbox-light | light | `accent_yellow` (#d79921) | page (#fbf1c7) | 2.19 | **FAIL** |
| gruvbox-light | light | `fg_dim` (#888270) | elevated (#d5c4a1) | 2.24 | **FAIL** |
| gruvbox-light | light | `accent_orange` (#d65d0e) | elevated (#d5c4a1) | 2.25 | **FAIL** |
| gruvbox-light | light | `accent_green` (#98971a) | surface (#ebdbb2) | 2.26 | **FAIL** |
| gruvbox-light | light | `accent_cyan` (#689d6a) | surface (#ebdbb2) | 2.31 | **FAIL** |
| gruvbox-light | light | `brand_pito` (#5170ff) | elevated (#d5c4a1) | 2.39 | **FAIL** |
| gruvbox-light | light | `accent_blue` (#458588) | elevated (#d5c4a1) | 2.47 | **FAIL** |
| gruvbox-light | light | `accent_purple` (#b16286) | elevated (#d5c4a1) | 2.47 | **FAIL** |
| gruvbox-light | light | `accent_green` (#98971a) | page (#fbf1c7) | 2.73 | **FAIL** |
| gruvbox-light | light | `accent_cyan` (#689d6a) | page (#fbf1c7) | 2.80 | **FAIL** |
| gruvbox-light | light | `fg_dim` (#888270) | surface (#ebdbb2) | 2.80 | **FAIL** |
| gruvbox-light | light | `accent_orange` (#d65d0e) | surface (#ebdbb2) | 2.82 | **FAIL** |
| gruvbox-light | light | `brand_pito` (#5170ff) | surface (#ebdbb2) | 2.99 | **FAIL** |
| gruvbox-light | light | `accent_blue` (#458588) | surface (#ebdbb2) | 3.08 | warn |
| gruvbox-light | light | `accent_purple` (#b16286) | surface (#ebdbb2) | 3.09 | warn |
| gruvbox-light | light | `accent_red` (#cc241d) | elevated (#d5c4a1) | 3.19 | warn |
| gruvbox-light | light | `fg_dim` (#888270) | page (#fbf1c7) | 3.38 | warn |
| gruvbox-light | light | `accent_orange` (#d65d0e) | page (#fbf1c7) | 3.41 | warn |
| gruvbox-light | light | `brand_pito` (#5170ff) | page (#fbf1c7) | 3.62 | warn |
| gruvbox-light | light | `accent_blue` (#458588) | page (#fbf1c7) | 3.73 | warn |
| gruvbox-light | light | `accent_purple` (#b16286) | page (#fbf1c7) | 3.73 | warn |
| gruvbox-light | light | `accent_red` (#cc241d) | surface (#ebdbb2) | 3.99 | warn |
| one-light | light | `accent_yellow` (#c18401) | elevated (#e3e3e4) | 2.49 | **FAIL** |
| one-light | light | `accent_green` (#50a14f) | elevated (#e3e3e4) | 2.50 | **FAIL** |
| one-light | light | `accent_yellow` (#c18401) | surface (#eeeeef) | 2.76 | **FAIL** |
| one-light | light | `accent_green` (#50a14f) | surface (#eeeeef) | 2.76 | **FAIL** |
| one-light | light | `fg_dim` (#86878c) | elevated (#e3e3e4) | 2.80 | **FAIL** |
| one-light | light | `accent_red` (#e45649) | elevated (#e3e3e4) | 2.86 | **FAIL** |
| one-light | light | `accent_yellow` (#c18401) | page (#fafafa) | 3.06 | warn |
| one-light | light | `accent_green` (#50a14f) | page (#fafafa) | 3.07 | warn |
| one-light | light | `fg_dim` (#86878c) | surface (#eeeeef) | 3.09 | warn |
| one-light | light | `accent_blue` (#4078f2) | elevated (#e3e3e4) | 3.16 | warn |
| one-light | light | `accent_red` (#e45649) | surface (#eeeeef) | 3.16 | warn |
| one-light | light | `brand_pito` (#5170ff) | elevated (#e3e3e4) | 3.20 | warn |
| one-light | light | `accent_cyan` (#0184bc) | elevated (#e3e3e4) | 3.26 | warn |
| one-light | light | `fg_dim` (#86878c) | page (#fafafa) | 3.43 | warn |
| one-light | light | `accent_blue` (#4078f2) | surface (#eeeeef) | 3.49 | warn |
| one-light | light | `accent_red` (#e45649) | page (#fafafa) | 3.51 | warn |
| one-light | light | `brand_pito` (#5170ff) | surface (#eeeeef) | 3.54 | warn |
| one-light | light | `accent_cyan` (#0184bc) | surface (#eeeeef) | 3.60 | warn |
| one-light | light | `accent_orange` (#986801) | elevated (#e3e3e4) | 3.79 | warn |
| one-light | light | `accent_blue` (#4078f2) | page (#fafafa) | 3.88 | warn |
| one-light | light | `brand_pito` (#5170ff) | page (#fafafa) | 3.94 | warn |
| one-light | light | `accent_cyan` (#0184bc) | page (#fafafa) | 4.00 | warn |
| one-light | light | `accent_orange` (#986801) | surface (#eeeeef) | 4.20 | warn |
| solarized-light | light | `fg_dim` (#a2aca9) | elevated (#ddd6c1) | 1.61 | **FAIL** |
| solarized-light | light | `fg_dim` (#a2aca9) | surface (#eee8d5) | 1.90 | **FAIL** |
| solarized-light | light | `fg_dim` (#a2aca9) | page (#fdf6e3) | 2.16 | **FAIL** |
| solarized-light | light | `accent_cyan` (#2aa198) | elevated (#ddd6c1) | 2.17 | **FAIL** |
| solarized-light | light | `accent_green` (#859900) | elevated (#ddd6c1) | 2.21 | **FAIL** |
| solarized-light | light | `accent_yellow` (#b58900) | elevated (#ddd6c1) | 2.21 | **FAIL** |
| solarized-light | light | `accent_blue` (#268bd2) | elevated (#ddd6c1) | 2.53 | **FAIL** |
| solarized-light | light | `accent_cyan` (#2aa198) | surface (#eee8d5) | 2.58 | **FAIL** |
| solarized-light | light | `accent_green` (#859900) | surface (#eee8d5) | 2.62 | **FAIL** |
| solarized-light | light | `accent_yellow` (#b58900) | surface (#eee8d5) | 2.62 | **FAIL** |
| solarized-light | light | `brand_pito` (#5170ff) | elevated (#ddd6c1) | 2.83 | **FAIL** |
| solarized-light | light | `accent_cyan` (#2aa198) | page (#fdf6e3) | 2.93 | **FAIL** |
| solarized-light | light | `accent_green` (#859900) | page (#fdf6e3) | 2.97 | **FAIL** |
| solarized-light | light | `accent_yellow` (#b58900) | page (#fdf6e3) | 2.98 | **FAIL** |
| solarized-light | light | `accent_blue` (#268bd2) | surface (#eee8d5) | 3.00 | warn |
| solarized-light | light | `accent_purple` (#6c71c4) | elevated (#ddd6c1) | 3.02 | warn |
| solarized-light | light | `fg_default` (#657b83) | elevated (#ddd6c1) | 3.07 | warn |
| solarized-light | light | `accent_orange` (#cb4b16) | elevated (#ddd6c1) | 3.17 | warn |
| solarized-light | light | `accent_red` (#dc322f) | elevated (#ddd6c1) | 3.19 | warn |
| solarized-light | light | `brand_pito` (#5170ff) | surface (#eee8d5) | 3.35 | warn |
| solarized-light | light | `accent_blue` (#268bd2) | page (#fdf6e3) | 3.41 | warn |
| solarized-light | light | `accent_purple` (#6c71c4) | surface (#eee8d5) | 3.57 | warn |
| solarized-light | light | `fg_default` (#657b83) | surface (#eee8d5) | 3.64 | warn |
| solarized-light | light | `accent_orange` (#cb4b16) | surface (#eee8d5) | 3.76 | warn |
| solarized-light | light | `accent_red` (#dc322f) | surface (#eee8d5) | 3.77 | warn |
| solarized-light | light | `brand_pito` (#5170ff) | page (#fdf6e3) | 3.81 | warn |
| solarized-light | light | `accent_purple` (#6c71c4) | page (#fdf6e3) | 4.06 | warn |
| solarized-light | light | `fg_default` (#657b83) | page (#fdf6e3) | 4.13 | warn |
| solarized-light | light | `accent_orange` (#cb4b16) | page (#fdf6e3) | 4.27 | warn |
| solarized-light | light | `accent_red` (#dc322f) | page (#fdf6e3) | 4.29 | warn |
| tomorrow | light | `accent_yellow` (#eab700) | elevated (#d6d6d6) | 1.28 | **FAIL** |
| tomorrow | light | `accent_yellow` (#eab700) | surface (#efefef) | 1.62 | **FAIL** |
| tomorrow | light | `accent_orange` (#f5871f) | elevated (#d6d6d6) | 1.73 | **FAIL** |
| tomorrow | light | `accent_yellow` (#eab700) | page (#ffffff) | 1.86 | **FAIL** |
| tomorrow | light | `fg_dim` (#949494) | elevated (#d6d6d6) | 2.09 | **FAIL** |
| tomorrow | light | `accent_orange` (#f5871f) | surface (#efefef) | 2.18 | **FAIL** |
| tomorrow | light | `accent_cyan` (#3e999f) | elevated (#d6d6d6) | 2.31 | **FAIL** |
| tomorrow | light | `accent_orange` (#f5871f) | page (#ffffff) | 2.51 | **FAIL** |
| tomorrow | light | `fg_dim` (#949494) | surface (#efefef) | 2.64 | **FAIL** |
| tomorrow | light | `accent_green` (#718c00) | elevated (#d6d6d6) | 2.65 | **FAIL** |
| tomorrow | light | `brand_pito` (#5170ff) | elevated (#d6d6d6) | 2.83 | **FAIL** |
| tomorrow | light | `accent_cyan` (#3e999f) | surface (#efefef) | 2.92 | **FAIL** |
| tomorrow | light | `fg_dim` (#949494) | page (#ffffff) | 3.03 | warn |
| tomorrow | light | `accent_green` (#718c00) | surface (#efefef) | 3.35 | warn |
| tomorrow | light | `accent_cyan` (#3e999f) | page (#ffffff) | 3.35 | warn |
| tomorrow | light | `accent_blue` (#4271ae) | elevated (#d6d6d6) | 3.44 | warn |
| tomorrow | light | `accent_purple` (#8959a8) | elevated (#d6d6d6) | 3.56 | warn |
| tomorrow | light | `brand_pito` (#5170ff) | surface (#efefef) | 3.57 | warn |
| tomorrow | light | `accent_red` (#c82829) | elevated (#d6d6d6) | 3.81 | warn |
| tomorrow | light | `accent_green` (#718c00) | page (#ffffff) | 3.85 | warn |
| tomorrow | light | `brand_pito` (#5170ff) | page (#ffffff) | 4.11 | warn |
| tomorrow | light | `accent_blue` (#4271ae) | surface (#efefef) | 4.34 | warn |
| ayu-dark | dark | `fg_dim` (#777775) | elevated (#1c212b) | 3.60 | warn |
| ayu-dark | dark | `brand_pito` (#5170ff) | elevated (#1c212b) | 3.93 | warn |
| ayu-dark | dark | `fg_dim` (#777775) | surface (#11151c) | 4.08 | warn |
| ayu-dark | dark | `fg_dim` (#777775) | page (#0b0e14) | 4.30 | warn |
| ayu-dark | dark | `brand_pito` (#5170ff) | surface (#11151c) | 4.45 | warn |
| ayu-mirage | dark | `brand_pito` (#5170ff) | elevated (#2b3340) | 3.10 | warn |
| ayu-mirage | dark | `brand_pito` (#5170ff) | surface (#232834) | 3.59 | warn |
| ayu-mirage | dark | `brand_pito` (#5170ff) | page (#1f2430) | 3.78 | warn |
| ayu-mirage | dark | `fg_dim` (#969794) | elevated (#2b3340) | 4.33 | warn |
| catppuccin-mocha | dark | `brand_pito` (#5170ff) | elevated (#45475a) | 2.22 | **FAIL** |
| catppuccin-mocha | dark | `fg_dim` (#878ca5) | elevated (#45475a) | 2.75 | **FAIL** |
| catppuccin-mocha | dark | `brand_pito` (#5170ff) | surface (#313244) | 3.06 | warn |
| catppuccin-mocha | dark | `fg_dim` (#878ca5) | surface (#313244) | 3.79 | warn |
| catppuccin-mocha | dark | `accent_red` (#f38ba8) | elevated (#45475a) | 3.94 | warn |
| catppuccin-mocha | dark | `brand_pito` (#5170ff) | page (#1e1e2e) | 3.99 | warn |
| catppuccin-mocha | dark | `accent_blue` (#89b4fa) | elevated (#45475a) | 4.33 | warn |
| catppuccin-mocha | dark | `accent_purple` (#cba6f7) | elevated (#45475a) | 4.49 | warn |
| dracula | dark | `fg_dim` (#6272a4) | elevated (#44475a) | 1.94 | **FAIL** |
| dracula | dark | `accent_blue` (#6272a4) | elevated (#44475a) | 1.94 | **FAIL** |
| dracula | dark | `brand_pito` (#5170ff) | elevated (#44475a) | 2.23 | **FAIL** |
| dracula | dark | `fg_dim` (#6272a4) | surface (#343641) | 2.55 | **FAIL** |
| dracula | dark | `accent_blue` (#6272a4) | surface (#343641) | 2.55 | **FAIL** |
| dracula | dark | `accent_red` (#ff5555) | elevated (#44475a) | 2.91 | **FAIL** |
| dracula | dark | `brand_pito` (#5170ff) | surface (#343641) | 2.92 | **FAIL** |
| dracula | dark | `fg_dim` (#6272a4) | page (#282a36) | 3.03 | warn |
| dracula | dark | `accent_blue` (#6272a4) | page (#282a36) | 3.03 | warn |
| dracula | dark | `brand_pito` (#5170ff) | page (#282a36) | 3.47 | warn |
| dracula | dark | `accent_purple` (#bd93f9) | elevated (#44475a) | 3.79 | warn |
| dracula | dark | `accent_red` (#ff5555) | surface (#343641) | 3.82 | warn |
| github-dark | dark | `brand_pito` (#5170ff) | elevated (#21262d) | 3.70 | warn |
| github-dark | dark | `fg_dim` (#7e848b) | elevated (#21262d) | 4.03 | warn |
| github-dark | dark | `brand_pito` (#5170ff) | surface (#161b22) | 4.21 | warn |
| gruvbox-dark | dark | `brand_pito` (#5170ff) | elevated (#504945) | 2.15 | **FAIL** |
| gruvbox-dark | dark | `accent_red` (#fb4934) | elevated (#504945) | 2.56 | **FAIL** |
| gruvbox-dark | dark | `brand_pito` (#5170ff) | surface (#3c3836) | 2.82 | **FAIL** |
| gruvbox-dark | dark | `fg_dim` (#9d937b) | elevated (#504945) | 2.90 | **FAIL** |
| gruvbox-dark | dark | `accent_purple` (#d3869b) | elevated (#504945) | 3.22 | warn |
| gruvbox-dark | dark | `accent_blue` (#83a598) | elevated (#504945) | 3.28 | warn |
| gruvbox-dark | dark | `accent_red` (#fb4934) | surface (#3c3836) | 3.37 | warn |
| gruvbox-dark | dark | `accent_orange` (#fe8019) | elevated (#504945) | 3.49 | warn |
| gruvbox-dark | dark | `brand_pito` (#5170ff) | page (#282828) | 3.59 | warn |
| gruvbox-dark | dark | `fg_dim` (#9d937b) | surface (#3c3836) | 3.81 | warn |
| gruvbox-dark | dark | `accent_cyan` (#8ec07c) | elevated (#504945) | 4.19 | warn |
| gruvbox-dark | dark | `accent_purple` (#d3869b) | surface (#3c3836) | 4.23 | warn |
| gruvbox-dark | dark | `accent_green` (#b8bb26) | elevated (#504945) | 4.27 | warn |
| gruvbox-dark | dark | `accent_red` (#fb4934) | page (#282828) | 4.29 | warn |
| gruvbox-dark | dark | `accent_blue` (#83a598) | surface (#3c3836) | 4.31 | warn |
| nord | dark | `brand_pito` (#5170ff) | elevated (#434c5e) | 2.10 | **FAIL** |
| nord | dark | `accent_red` (#bf616a) | elevated (#434c5e) | 2.11 | **FAIL** |
| nord | dark | `brand_pito` (#5170ff) | surface (#3b4252) | 2.45 | **FAIL** |
| nord | dark | `accent_red` (#bf616a) | surface (#3b4252) | 2.46 | **FAIL** |
| nord | dark | `accent_orange` (#d08770) | elevated (#434c5e) | 3.03 | warn |
| nord | dark | `brand_pito` (#5170ff) | page (#2e3440) | 3.04 | warn |
| nord | dark | `accent_purple` (#b48ead) | elevated (#434c5e) | 3.05 | warn |
| nord | dark | `fg_dim` (#949aa5) | elevated (#434c5e) | 3.05 | warn |
| nord | dark | `accent_red` (#bf616a) | page (#2e3440) | 3.05 | warn |
| nord | dark | `accent_blue` (#81a1c1) | elevated (#434c5e) | 3.21 | warn |
| nord | dark | `accent_orange` (#d08770) | surface (#3b4252) | 3.54 | warn |
| nord | dark | `accent_purple` (#b48ead) | surface (#3b4252) | 3.55 | warn |
| nord | dark | `fg_dim` (#949aa5) | surface (#3b4252) | 3.56 | warn |
| nord | dark | `accent_blue` (#81a1c1) | surface (#3b4252) | 3.74 | warn |
| nord | dark | `accent_green` (#a3be8c) | elevated (#434c5e) | 4.23 | warn |
| nord | dark | `accent_cyan` (#88c0d0) | elevated (#434c5e) | 4.31 | warn |
| nord | dark | `accent_orange` (#d08770) | page (#2e3440) | 4.39 | warn |
| nord | dark | `accent_purple` (#b48ead) | page (#2e3440) | 4.41 | warn |
| nord | dark | `fg_dim` (#949aa5) | page (#2e3440) | 4.42 | warn |
| one-dark | dark | `fg_dim` (#777c87) | elevated (#2c313a) | 3.12 | warn |
| one-dark | dark | `brand_pito` (#5170ff) | elevated (#2c313a) | 3.18 | warn |
| one-dark | dark | `fg_dim` (#777c87) | page (#282c34) | 3.34 | warn |
| one-dark | dark | `brand_pito` (#5170ff) | page (#282c34) | 3.41 | warn |
| one-dark | dark | `fg_dim` (#777c87) | surface (#21252b) | 3.68 | warn |
| one-dark | dark | `brand_pito` (#5170ff) | surface (#21252b) | 3.75 | warn |
| one-dark | dark | `accent_red` (#e06c75) | elevated (#2c313a) | 4.09 | warn |
| one-dark | dark | `accent_red` (#e06c75) | page (#282c34) | 4.38 | warn |
| one-dark | dark | `accent_purple` (#c678dd) | elevated (#2c313a) | 4.44 | warn |
| solarized-dark | dark | `fg_dim` (#4f6a70) | elevated (#0a4a59) | 1.70 | **FAIL** |
| solarized-dark | dark | `accent_red` (#dc322f) | elevated (#0a4a59) | 2.12 | **FAIL** |
| solarized-dark | dark | `accent_orange` (#cb4b16) | elevated (#0a4a59) | 2.13 | **FAIL** |
| solarized-dark | dark | `accent_purple` (#6c71c4) | elevated (#0a4a59) | 2.24 | **FAIL** |
| solarized-dark | dark | `fg_dim` (#4f6a70) | surface (#073642) | 2.25 | **FAIL** |
| solarized-dark | dark | `brand_pito` (#5170ff) | elevated (#0a4a59) | 2.39 | **FAIL** |
| solarized-dark | dark | `fg_dim` (#4f6a70) | page (#002b36) | 2.59 | **FAIL** |
| solarized-dark | dark | `accent_blue` (#268bd2) | elevated (#0a4a59) | 2.67 | **FAIL** |
| solarized-dark | dark | `accent_red` (#dc322f) | surface (#073642) | 2.81 | **FAIL** |
| solarized-dark | dark | `accent_orange` (#cb4b16) | surface (#073642) | 2.82 | **FAIL** |
| solarized-dark | dark | `accent_purple` (#6c71c4) | surface (#073642) | 2.97 | **FAIL** |
| solarized-dark | dark | `accent_yellow` (#b58900) | elevated (#0a4a59) | 3.06 | warn |
| solarized-dark | dark | `accent_green` (#859900) | elevated (#0a4a59) | 3.07 | warn |
| solarized-dark | dark | `fg_default` (#839496) | elevated (#0a4a59) | 3.11 | warn |
| solarized-dark | dark | `accent_cyan` (#2aa198) | elevated (#0a4a59) | 3.11 | warn |
| solarized-dark | dark | `brand_pito` (#5170ff) | surface (#073642) | 3.16 | warn |
| solarized-dark | dark | `accent_red` (#dc322f) | page (#002b36) | 3.25 | warn |
| solarized-dark | dark | `accent_orange` (#cb4b16) | page (#002b36) | 3.26 | warn |
| solarized-dark | dark | `accent_purple` (#6c71c4) | page (#002b36) | 3.43 | warn |
| solarized-dark | dark | `accent_blue` (#268bd2) | surface (#073642) | 3.53 | warn |
| solarized-dark | dark | `brand_pito` (#5170ff) | page (#002b36) | 3.65 | warn |
| solarized-dark | dark | `accent_yellow` (#b58900) | surface (#073642) | 4.05 | warn |
| solarized-dark | dark | `accent_green` (#859900) | surface (#073642) | 4.06 | warn |
| solarized-dark | dark | `accent_blue` (#268bd2) | page (#002b36) | 4.08 | warn |
| solarized-dark | dark | `fg_default` (#839496) | surface (#073642) | 4.11 | warn |
| solarized-dark | dark | `accent_cyan` (#2aa198) | surface (#073642) | 4.12 | warn |
| tokyo-night | dark | `fg_dim` (#565f89) | elevated (#24283b) | 2.35 | **FAIL** |
| tokyo-night | dark | `fg_dim` (#565f89) | surface (#1f2335) | 2.51 | **FAIL** |
| tokyo-night | dark | `fg_dim` (#565f89) | page (#1a1b26) | 2.76 | **FAIL** |
| tokyo-night | dark | `brand_pito` (#5170ff) | elevated (#24283b) | 3.55 | warn |
| tokyo-night | dark | `brand_pito` (#5170ff) | surface (#1f2335) | 3.79 | warn |
| tokyo-night | dark | `brand_pito` (#5170ff) | page (#1a1b26) | 4.16 | warn |
| tomorrow-night | dark | `brand_pito` (#5170ff) | elevated (#373b41) | 2.74 | **FAIL** |
| tomorrow-night | dark | `fg_dim` (#828484) | elevated (#373b41) | 2.99 | **FAIL** |
| tomorrow-night | dark | `accent_red` (#cc6666) | elevated (#373b41) | 3.04 | warn |
| tomorrow-night | dark | `brand_pito` (#5170ff) | surface (#282a2e) | 3.50 | warn |
| tomorrow-night | dark | `fg_dim` (#828484) | surface (#282a2e) | 3.82 | warn |
| tomorrow-night | dark | `accent_red` (#cc6666) | surface (#282a2e) | 3.87 | warn |
| tomorrow-night | dark | `brand_pito` (#5170ff) | page (#1d1f21) | 4.02 | warn |
| tomorrow-night | dark | `accent_blue` (#81a2be) | elevated (#373b41) | 4.21 | warn |
| tomorrow-night | dark | `accent_purple` (#b294bb) | elevated (#373b41) | 4.21 | warn |
| tomorrow-night | dark | `fg_dim` (#828484) | page (#1d1f21) | 4.40 | warn |
| tomorrow-night | dark | `accent_red` (#cc6666) | page (#1d1f21) | 4.46 | warn |

## fg_faded (placeholder/disabled — low contrast partly by design)

| theme | mode | on | ratio | status |
|---|---|---|---:|---|
| ayu-light | light | elevated | 1.54 | FAIL |
| ayu-light | light | surface | 1.69 | FAIL |
| ayu-light | light | page | 1.82 | FAIL |
| catppuccin-latte | light | elevated | 2.17 | FAIL |
| catppuccin-latte | light | surface | 2.56 | FAIL |
| catppuccin-latte | light | page | 3.49 | warn |
| github-light | light | elevated | 2.02 | FAIL |
| github-light | light | surface | 2.21 | FAIL |
| github-light | light | page | 2.36 | FAIL |
| gruvbox-light | light | elevated | 1.40 | FAIL |
| gruvbox-light | light | surface | 1.75 | FAIL |
| gruvbox-light | light | page | 2.12 | FAIL |
| one-light | light | elevated | 1.75 | FAIL |
| one-light | light | surface | 1.94 | FAIL |
| one-light | light | page | 2.15 | FAIL |
| solarized-light | light | elevated | 1.21 | FAIL |
| solarized-light | light | surface | 1.43 | FAIL |
| solarized-light | light | page | 1.63 | FAIL |
| tomorrow | light | elevated | 1.37 | FAIL |
| tomorrow | light | surface | 1.73 | FAIL |
| tomorrow | light | page | 1.99 | FAIL |
| ayu-dark | dark | elevated | 2.13 | FAIL |
| ayu-dark | dark | surface | 2.41 | FAIL |
| ayu-dark | dark | page | 2.55 | FAIL |
| ayu-mirage | dark | elevated | 2.57 | FAIL |
| ayu-mirage | dark | surface | 2.97 | FAIL |
| ayu-mirage | dark | page | 3.13 | warn |
| catppuccin-mocha | dark | elevated | 1.66 | FAIL |
| catppuccin-mocha | dark | surface | 2.29 | FAIL |
| catppuccin-mocha | dark | page | 2.98 | FAIL |
| dracula | dark | elevated | 2.20 | FAIL |
| dracula | dark | surface | 2.88 | FAIL |
| dracula | dark | page | 3.42 | warn |
| github-dark | dark | elevated | 2.32 | FAIL |
| github-dark | dark | surface | 2.64 | FAIL |
| github-dark | dark | page | 2.89 | FAIL |
| gruvbox-dark | dark | elevated | 1.79 | FAIL |
| gruvbox-dark | dark | surface | 2.35 | FAIL |
| gruvbox-dark | dark | page | 2.99 | FAIL |
| nord | dark | elevated | 1.95 | FAIL |
| nord | dark | surface | 2.27 | FAIL |
| nord | dark | page | 2.82 | FAIL |
| one-dark | dark | elevated | 2.13 | FAIL |
| one-dark | dark | page | 2.28 | FAIL |
| one-dark | dark | surface | 2.51 | FAIL |
| solarized-dark | dark | elevated | 1.22 | FAIL |
| solarized-dark | dark | surface | 1.61 | FAIL |
| solarized-dark | dark | page | 1.86 | FAIL |
| tokyo-night | dark | elevated | 1.63 | FAIL |
| tokyo-night | dark | surface | 1.74 | FAIL |
| tokyo-night | dark | page | 1.91 | FAIL |
| tomorrow-night | dark | elevated | 1.86 | FAIL |
| tomorrow-night | dark | surface | 2.37 | FAIL |
| tomorrow-night | dark | page | 2.73 | FAIL |

## Full matrix — light themes (the ones you flagged)

### ayu-light  (page #fcfcfc, surface #f3f4f5, elevated #e7eaed)
| text token | page | surface | elevated |
|---|---:|---:|---:|
| `fg_default` #5c6166 | 6.10 ✅ | 5.68 ✅ | 5.18 ✅ |
| `fg_dim` #9c9fa2 | 2.59 ❌ | 2.42 ❌ | 2.20 ❌ |
| `fg_faded` #bcbec0 | 1.82 ❌ | 1.69 ❌ | 1.54 ❌ |
| `accent_purple` #a37acc | 3.29 ⚠️ | 3.07 ⚠️ | 2.80 ❌ |
| `accent_blue` #399ee6 | 2.84 ❌ | 2.65 ❌ | 2.41 ❌ |
| `accent_cyan` #4cbf99 | 2.22 ❌ | 2.07 ❌ | 1.89 ❌ |
| `accent_green` #86b300 | 2.42 ❌ | 2.25 ❌ | 2.06 ❌ |
| `accent_yellow` #f2ae49 | 1.87 ❌ | 1.75 ❌ | 1.59 ❌ |
| `accent_orange` #fa8d3e | 2.29 ❌ | 2.13 ❌ | 1.94 ❌ |
| `accent_red` #f07171 | 2.80 ❌ | 2.61 ❌ | 2.38 ❌ |
| `brand_pito` #5170ff | 4.00 ⚠️ | 3.73 ⚠️ | 3.40 ⚠️ |

### catppuccin-latte  (page #eff1f5, surface #ccd0da, elevated #bcc0cc)
| text token | page | surface | elevated |
|---|---:|---:|---:|
| `fg_default` #4c4f69 | 7.06 ✅ | 5.17 ✅ | 4.39 ⚠️ |
| `fg_dim` #5c5f77 | 5.53 ✅ | 4.05 ⚠️ | 3.44 ⚠️ |
| `fg_faded` #7c7f93 | 3.49 ⚠️ | 2.56 ❌ | 2.17 ❌ |
| `accent_purple` #8839ef | 4.79 ✅ | 3.51 ⚠️ | 2.98 ❌ |
| `accent_blue` #1e66f5 | 4.34 ⚠️ | 3.18 ⚠️ | 2.70 ❌ |
| `accent_cyan` #179299 | 3.31 ⚠️ | 2.43 ❌ | 2.06 ❌ |
| `accent_green` #40a02b | 2.96 ❌ | 2.17 ❌ | 1.84 ❌ |
| `accent_yellow` #df8e1d | 2.31 ❌ | 1.70 ❌ | 1.44 ❌ |
| `accent_orange` #fe640b | 2.64 ❌ | 1.93 ❌ | 1.64 ❌ |
| `accent_red` #d20f39 | 4.80 ✅ | 3.52 ⚠️ | 2.99 ❌ |
| `brand_pito` #5170ff | 3.63 ⚠️ | 2.66 ❌ | 2.26 ❌ |

### github-light  (page #ffffff, surface #f6f8fa, elevated #eaeef2)
| text token | page | surface | elevated |
|---|---:|---:|---:|
| `fg_default` #24292f | 14.65 ✅ | 13.76 ✅ | 12.57 ✅ |
| `fg_dim` #7c7f82 | 4.03 ⚠️ | 3.78 ⚠️ | 3.45 ⚠️ |
| `fg_faded` #a7a9ac | 2.36 ❌ | 2.21 ❌ | 2.02 ❌ |
| `accent_purple` #8250df | 5.05 ✅ | 4.74 ✅ | 4.33 ⚠️ |
| `accent_blue` #0969da | 5.19 ✅ | 4.88 ✅ | 4.45 ⚠️ |
| `accent_cyan` #1b7c83 | 4.93 ✅ | 4.63 ✅ | 4.23 ⚠️ |
| `accent_green` #1a7f37 | 5.08 ✅ | 4.77 ✅ | 4.36 ⚠️ |
| `accent_yellow` #9a6700 | 4.87 ✅ | 4.57 ✅ | 4.17 ⚠️ |
| `accent_orange` #bc4c00 | 5.03 ✅ | 4.73 ✅ | 4.32 ⚠️ |
| `accent_red` #cf222e | 5.36 ✅ | 5.03 ✅ | 4.59 ✅ |
| `brand_pito` #5170ff | 4.11 ⚠️ | 3.86 ⚠️ | 3.52 ⚠️ |

### gruvbox-light  (page #fbf1c7, surface #ebdbb2, elevated #d5c4a1)
| text token | page | surface | elevated |
|---|---:|---:|---:|
| `fg_default` #3c3836 | 10.22 ✅ | 8.45 ✅ | 6.76 ✅ |
| `fg_dim` #888270 | 3.38 ⚠️ | 2.80 ❌ | 2.24 ❌ |
| `fg_faded` #afa78d | 2.12 ❌ | 1.75 ❌ | 1.40 ❌ |
| `accent_purple` #b16286 | 3.73 ⚠️ | 3.09 ⚠️ | 2.47 ❌ |
| `accent_blue` #458588 | 3.73 ⚠️ | 3.08 ⚠️ | 2.47 ❌ |
| `accent_cyan` #689d6a | 2.80 ❌ | 2.31 ❌ | 1.85 ❌ |
| `accent_green` #98971a | 2.73 ❌ | 2.26 ❌ | 1.81 ❌ |
| `accent_yellow` #d79921 | 2.19 ❌ | 1.81 ❌ | 1.45 ❌ |
| `accent_orange` #d65d0e | 3.41 ⚠️ | 2.82 ❌ | 2.25 ❌ |
| `accent_red` #cc241d | 4.82 ✅ | 3.99 ⚠️ | 3.19 ⚠️ |
| `brand_pito` #5170ff | 3.62 ⚠️ | 2.99 ❌ | 2.39 ❌ |

### one-light  (page #fafafa, surface #eeeeef, elevated #e3e3e4)
| text token | page | surface | elevated |
|---|---:|---:|---:|
| `fg_default` #383a42 | 10.86 ✅ | 9.78 ✅ | 8.84 ✅ |
| `fg_dim` #86878c | 3.43 ⚠️ | 3.09 ⚠️ | 2.80 ❌ |
| `fg_faded` #acadb0 | 2.15 ❌ | 1.94 ❌ | 1.75 ❌ |
| `accent_purple` #a626a4 | 5.86 ✅ | 5.27 ✅ | 4.77 ✅ |
| `accent_blue` #4078f2 | 3.88 ⚠️ | 3.49 ⚠️ | 3.16 ⚠️ |
| `accent_cyan` #0184bc | 4.00 ⚠️ | 3.60 ⚠️ | 3.26 ⚠️ |
| `accent_green` #50a14f | 3.07 ⚠️ | 2.76 ❌ | 2.50 ❌ |
| `accent_yellow` #c18401 | 3.06 ⚠️ | 2.76 ❌ | 2.49 ❌ |
| `accent_orange` #986801 | 4.66 ✅ | 4.20 ⚠️ | 3.79 ⚠️ |
| `accent_red` #e45649 | 3.51 ⚠️ | 3.16 ⚠️ | 2.86 ❌ |
| `brand_pito` #5170ff | 3.94 ⚠️ | 3.54 ⚠️ | 3.20 ⚠️ |

### solarized-light  (page #fdf6e3, surface #eee8d5, elevated #ddd6c1)
| text token | page | surface | elevated |
|---|---:|---:|---:|
| `fg_default` #657b83 | 4.13 ⚠️ | 3.64 ⚠️ | 3.07 ⚠️ |
| `fg_dim` #a2aca9 | 2.16 ❌ | 1.90 ❌ | 1.61 ❌ |
| `fg_faded` #c0c5bd | 1.63 ❌ | 1.43 ❌ | 1.21 ❌ |
| `accent_purple` #6c71c4 | 4.06 ⚠️ | 3.57 ⚠️ | 3.02 ⚠️ |
| `accent_blue` #268bd2 | 3.41 ⚠️ | 3.00 ⚠️ | 2.53 ❌ |
| `accent_cyan` #2aa198 | 2.93 ❌ | 2.58 ❌ | 2.17 ❌ |
| `accent_green` #859900 | 2.97 ❌ | 2.62 ❌ | 2.21 ❌ |
| `accent_yellow` #b58900 | 2.98 ❌ | 2.62 ❌ | 2.21 ❌ |
| `accent_orange` #cb4b16 | 4.27 ⚠️ | 3.76 ⚠️ | 3.17 ⚠️ |
| `accent_red` #dc322f | 4.29 ⚠️ | 3.77 ⚠️ | 3.19 ⚠️ |
| `brand_pito` #5170ff | 3.81 ⚠️ | 3.35 ⚠️ | 2.83 ❌ |

### tomorrow  (page #ffffff, surface #efefef, elevated #d6d6d6)
| text token | page | surface | elevated |
|---|---:|---:|---:|
| `fg_default` #4d4d4c | 8.46 ✅ | 7.36 ✅ | 5.82 ✅ |
| `fg_dim` #949494 | 3.03 ⚠️ | 2.64 ❌ | 2.09 ❌ |
| `fg_faded` #b8b8b7 | 1.99 ❌ | 1.73 ❌ | 1.37 ❌ |
| `accent_purple` #8959a8 | 5.17 ✅ | 4.50 ✅ | 3.56 ⚠️ |
| `accent_blue` #4271ae | 4.99 ✅ | 4.34 ⚠️ | 3.44 ⚠️ |
| `accent_cyan` #3e999f | 3.35 ⚠️ | 2.92 ❌ | 2.31 ❌ |
| `accent_green` #718c00 | 3.85 ⚠️ | 3.35 ⚠️ | 2.65 ❌ |
| `accent_yellow` #eab700 | 1.86 ❌ | 1.62 ❌ | 1.28 ❌ |
| `accent_orange` #f5871f | 2.51 ❌ | 2.18 ❌ | 1.73 ❌ |
| `accent_red` #c82829 | 5.54 ✅ | 4.82 ✅ | 3.81 ⚠️ |
| `brand_pito` #5170ff | 4.11 ⚠️ | 3.57 ⚠️ | 2.83 ❌ |

## Summary counts
- Themes: 18 (7 light, 11 dark)
- Real-text FAILs (<3.0): 120
- Real-text warns (3.0–4.5): 163
- Of those, on light themes: FAIL 87, warn 78
