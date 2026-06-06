# Validations — your review queue (PR #62)

> Running list of things **you** need to validate/decide before merging PR #62.
> Everything is committed (reversible); this file accumulates as work lands. Tick
> `[x]` as you clear each, or leave a note. Nothing here blocks further building.

## Decisions pending (I act once you pick)

- [ ] **Diff-reveal granularity — char vs line.** Run `/themes list`, grab the
      message handle, then on a **dark** theme `#<handle> apply dracula` (char:
      list reverse-deletes char-by-char, quip types in) vs a **light** theme
      `#<handle> apply github-light` (line: chunkier, line-at-a-time). Pick the
      keeper → I do T12.14 (delete the loser + add the kept approach's Vitest
      specs). _(docs/themes.md P12b/T12.13)_
- [ ] **Plan sign-off (optional).** Want a formal audit pass on `docs/themes.md`
      and `docs/copy-engine.md` via plan-author **audit mode**? Say the word.

## Behaviour to smoke-test

- [ ] **/themes sidebar** — bare `/themes`: ↑/↓ live-preview, Enter applies, Esc
      reverts the preview to the saved theme, current theme marked ●.
- [ ] **/themes command** — `list` + `ls` (System message, grouped Dark/Light),
      `preview`/`apply`/`reset`, `/themes <name>` shorthand, `default`, `--help`.
- [ ] **Persistence + brand** — applied theme survives reload; pito brand blue
      identical on every theme; light themes readable (chatbox, segments,
      sidebar, palette, mini-status).
- [ ] **Follow-up replies** — `#<handle> preview <name>` marks the row
      (repeatable); `#<handle> apply <name>` morphs to the witty confirmation +
      consumes the list (hashtag gone).
- [ ] **Confirmations CHANGED** — `/disconnect …` then `#<handle> confirm` now
      **echoes + appends** a new outcome message (orange border + surface bg) and
      **consumes** the original prompt (it is NOT mutated in place anymore).
      Verify the destructive disconnect path end-to-end. `#<handle> cancel` too.

## Copy review (optional — i18n-only changes, easy to tweak)

- [ ] **Voice/length on enriched pools.** All dictionaries are now 50 variants.
      Skim the freshly written ones and flag any you want reworded (I adjust
      i18n, no code): `pito.copy.confirmation.*`, `pito.copy.disconnect.*`,
      `pito.copy.connect.not_configured`, `pito.copy.auth.not_enrolled`,
      `pito.copy.help.body`, `pito.copy.theme.{list_intro,sidebar_placeholder}`,
      `pito.copy.theme.applied`, `pito.copy.thinking.confirmation.*`,
      `pito.copy.youtube.ascii_art`. Tool: `bin/rails pito:copy:audit`.

## Bugs found during your validation

- [x] **FIXED — theme Registry emptied after a dev reload** → `/themes <name>` &
      `default` said "not found in registry" and the sidebar rendered no rows.
      Root cause: `require`-once vs Zeitwerk reload. Fixed `7349a381` (`load`).
- [x] **FIXED — missing `slash.help.more_hint`/`fewer_hint` i18n** (the
      `ctrl+|` "translation missing") + **stripped "· Esc close"** from the
      themes sidebar hint. `05124807`.
- [x] **FIXED — catppuccin-latte low-contrast** chatbox/timestamp text
      (`fg-dim`/`fg-faded` pinned to canonical subtext/overlay). `d4456d22`.
- [ ] **RE-TEST — `/themes` sidebar preview/Esc.** The "preview applied / Esc
      keeps it" symptom was almost certainly the registry-empty bug above
      (apply 422'd against the empty registry while the visual preview lingered
      until reload). Re-test now that the registry is fixed; if preview still
      sticks after Esc, tell me and I'll dig into `theme_nav_controller`.

## Merge

- [ ] **PR #62** — do NOT merge until the above are cleared; then squash-merge.

---

_Done already (no action needed): CI green (rails/js/prettier); full suite green
(rspec/npm/rubocop/zeitwerk); agents repo consolidated to plan-author (audits
too) + plan-runner._
