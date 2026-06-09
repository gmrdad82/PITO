# list games — table, platforms, release date, suggestions

> Status: Running (plan-runner) — current branch `cleanup-fixups`.

## Sign-off

- [x] Drafted
- [x] Audited

## Context

`list games` is the games-domain list command in the conversational shell. Four
problems, all traced to root cause in the current branch:

1. **Multi-column table collapses to a vertical list.** `list games with developer,
   publisher, genres, release date, year, platforms` renders each header on its own
   line instead of a table. Root cause: `Pito::Event::SystemComponent#table_grid_cols`
   builds a Tailwind arbitrary class at *runtime* (`grid-cols-[max-content_…_1fr]`).
   Tailwind v4 only compiles classes it scans in source (`@source "../../components"`);
   the only literal in source is the 2-col `grid-cols-[max-content_1fr]`. Any N≥3 string
   is never compiled → the element keeps `display:grid` with **no** `grid-template-columns`
   → one implicit column → vertical stack. User wants columns that **wrap** and stay
   compact — not `max-content` columns that expand to full content width.

2. **Platforms show raw IGDB names.** The platform column joins `g.platforms` verbatim →
   "Google Stadia, Xbox Series X|S, PlayStation 4, Nintendo Switch 2, PC (Microsoft
   Windows)…". User wants ONLY 3 pito tokens, labelled **PlayStation / Switch / Steam**
   (Xbox/Google/Mac/PC names dropped). A working token mapping already exists but is
   private to the detail card (`app/components/pito/game/detail_component.rb:13-69`,
   `IGDB_TO_TOKEN` + `platform_tokens`/`platforms_label`). Raw names stay stored; only
   display + sort normalize.

3. **Release date column isn't routed through a formatter.** User wants it formatted via
   `Pito::Formatter` like "June 09, 2026". `Game#release_label` (`app/models/game.rb:76-97`)
   already produces this for full-precision dates (and partial labels / "TBA" otherwise)
   but the logic lives in the model, not in the `Pito::Formatter::*` family of pure
   functions.

4. **Autocomplete is wrong after `list games`.** After `list games ` the ghost should be
   ` with` but the user sees "channels"; `list games with ` offers no fields. Root cause:
   the server engine *does* compute clause ghosts (`Pito::Suggestions::ListClauseGhost`)
   but the JS client never defers to it for the `list` verb — `_computeLocalGhost` resolves
   the static `:noun` slot locally (`app/javascript/controllers/pito/suggestions_controller.js:583-653`).
   And nothing suggests the ` with` connector after the noun (`ListClauseGhost.ghost`
   returns nil unless a `with`/`sorted by` clause is already present). The `with` options
   must be exactly platform|platforms, genre|genres, developer|dev, publisher, release
   date, year — **no channels** in the `with` list (`ListClauseGhost.registry_for` already
   excludes channels). The bare `list ` "channels" default is fine and stays. Channel
   filtering is the separate Shift+Tab handle mechanism (`chat_form_controller.js`), out of
   scope. Videos/channels suggestions are a later session — focus is `list games`.

Outcome: clean wrapping multi-column table; platforms shown as PlayStation/Switch/Steam
only; release date via a `Pito::Formatter`; and `list games` autocomplete that ghosts
` with` then the field tokens, never "channels". Specs added in both Rails (RSpec) and JS
(vitest).

## North star

`list games with developer, publisher, genres, release date, year, platforms` renders a
compact, word-wrapping table; platform cells read "PlayStation, Switch, Steam"; release
dates read "June 09, 2026"; and the input ghosts ` with` → field tokens as you type.

## Locked decisions

- **Reuse the existing mapping — don't reinvent.** The detail card already has the working
  mechanism: `IGDB_TO_TOKEN` (an `[regex, token]` array) + `#platform_tokens` +
  `#platforms_label` (`app/components/pito/game/detail_component.rb:13-69`). We **extract
  that verbatim** into a shared module and **broaden the existing regexes** in place — same
  array shape, same method semantics.
- **Platform labels:** `ps → PlayStation`, `switch → Switch`, `steam → Steam`. Three buckets,
  matched case-insensitively against each raw IGDB name (broadened `IGDB_TO_TOKEN` entries):
  - **PlayStation** ← `/playstation|ps\s?\d/i` (PS5, PS4, PlayStation 3, Playstation 4, …).
  - **Switch** ← `/switch/i` (Nintendo Switch, Switch 2, Switch Gen 1, …).
  - **Steam** (PC bucket) ← `/steam|pc|windows|gog|epic|amazon|battle\.?net/i`.
  Everything else is **dropped** from display — Xbox*, Google Stadia, Mac, etc. Generation-
  specific labels rejected (buckets are coarse).
- **Platforms stored unchanged.** Only display + the platform sort key normalize.
- **Table grid uses a CSS class + a `data-cols` attribute** (like `data-accent`) selecting
  static, compiled `.pito-data-grid[data-cols="N"]` rules. **No inline style, no runtime
  Tailwind arbitrary classes.** First two columns (`#`, Game/key) are content-sized
  defaults; every extra `with` column is an equally-spaced, wrap-capable `1fr` track.
- **Single source of truth for `list` ghosts is the server.** The JS client defers the whole
  `list` verb to `POST /suggestions` (returns `null` from `_computeLocalGhost`); the server's
  `ListClauseGhost` + `compute_ghost` drive noun completion, the ` with` connector, the
  `with`/`sorted by` field tokens, and channel exclusion.
- **Noun vocab order unchanged** (`%w[channels videos games]` — natural to the user). The bare
  `list ` default ghost stays "channels"; that is acceptable. Scope is `list games` only —
  videos/channels suggestions are a later session.
- Plan tiers `[manual|low|high]`; no `[skipci]`; current branch (`cleanup-fixups`); specs on;
  plain imperative commit messages, no co-author trailer.
- **Drop misaligned legacy.** When a verb is redefined, remove everything that no longer
  matches the new direction — code, specs, comments, copy, confirmations — for that verb.
  No dead leftovers. Applies to every verb rework below.

## Phase index

- **Phase 1 — Platform tokens (display + sort), PlayStation/Switch/Steam**
- **Phase 2 — Release date via `Pito::Formatter`**
- **Phase 3 — Wrapping multi-column table grid**
- **Phase 4 — `list games` autocomplete: ` with` connector + field tokens**
- **Phase 5 — Help message rewrite + `list games --help`**
- **Phase 6 — Polish (post-review tweaks) + platform engine**
- **Phase 7 — `--help` man page for every chat verb**
- **Phase 8 — Per-noun `list --help` (games ✅ / channels / videos)**
- **Phase 9 — `show game --help` / `show video --help`**
- **Phase 10 — Fix `show game` / `show video` implementation**
- **Phase 11 — `import videos --help` / `import game --help`**
- **Phase 12 — Fix `import videos` / `import game` implementation**
- **Phase 13 — `sync videos --help` / `sync channels --help`**
- **Phase 14 — Rework `sync` implementation (drop `sync game` + legacy forms)**
- **Phase 15 — `footage game --help`**
- **Phase 16 — Rework `footage game` implementation (id only, no title)**
- **Phase 17 — `delete game --help` / `delete video --help`**
- **Phase 18 — Rework `delete game` / `delete video` implementation (id only)**
- **Phase 19 — `reindex game --help` / `reindex video --help`**
- **Phase 20 — Rework `reindex game` / `reindex video` implementation (id only)**
- **Phase 21 — `publish video --help` / `unlist video --help` / `schedule video --help`**
- **Phase 22 — Rework `publish` / `unlist` / `schedule` video implementation (id only)**
- **Phase 23 — `link`/`unlink` `game`/`video` `--help`**
- **Phase 24 — Rework `link` / `unlink` implementation (local ids only)**

---

## Phase 1 — Platform tokens (display + sort)

- [x] T1.1 Create `docs/list-games.md` with this file's full content. complexity: [manual]
- [x] T1.2 Move the existing `IGDB_TO_TOKEN` array, `#platform_tokens`, and `#platforms_label` verbatim out of `detail_component.rb` into new `app/services/pito/game/platform_tokens.rb` (module `Pito::Game::PlatformTokens`, `module_function`), keeping the `[regex, token]` shape; methods take `platforms` instead of reading `@game`. complexity: [low]
- [x] T1.3 Broaden the moved `IGDB_TO_TOKEN` regexes in place to the three buckets (Locked decisions): PlayStation `/playstation|ps\s?\d/i`, Switch `/switch/i`, Steam `/steam|pc|windows|gog|epic|amazon|battle\.?net/i`. complexity: [low]
- [x] T1.4 Expose `tokens(platforms)` and `labels(platforms)` as the module's public entrypoints (label = the existing `I18n.t(...platform_label.#{token})` join). complexity: [low]
- [x] T1.5 Update the label key from `pito.game.detail.platform_label` to a shared `pito.game.platform_label` in `config/locales/pito/game/en.yml`; set `switch: Switch` (was "Nintendo Switch"). complexity: [low]
- [x] T1.6 Replace `DetailComponent#platform_tokens`/`#platforms_label` with thin calls to `Pito::Game::PlatformTokens` (pass `@game.platforms`); the template keeps calling `platforms_label`. complexity: [low]
- [x] T1.7 Change the `:platform` column `value:` proc in `app/services/pito/message_builder/game/list_columns.rb` to `->(g) { Pito::Game::PlatformTokens.labels(g.platforms).to_s }`. complexity: [low]
- [x] T1.8 Change the `:platform` `SORT_SPECS` key in the same file to sort on `PlatformTokens.labels(g).to_s` so sort matches display. complexity: [low]
- [x] T1.9 Create `spec/services/pito/game/platform_tokens_spec.rb`: assert each bucket (PS5/PS4/"PlayStation 3"→ps; "Nintendo Switch 2"/"Switch Gen 1"→switch; Steam/"PC (Microsoft Windows)"/GOG/Epic/Amazon/Battle.net→steam), Xbox*/Google Stadia/Mac dropped, and de-dup (PS4+PS5 → one PlayStation). complexity: [low]
- [x] T1.10 Add a `list_columns` spec example asserting the platform cell renders normalized labels (no raw IGDB names). complexity: [low]
- [x] T1.11 Update the detail-component spec for the "Switch" label (was "Nintendo Switch") and the moved locale key. complexity: [low]
- [x] T1.12 Run `bundle exec rspec` for the touched specs; `bin/rubocop` clean. complexity: [low]
- [x] T1.13 Commit: "Normalize game platforms to PlayStation/Switch/Steam in list + detail". complexity: [manual]

## Phase 2 — Release date via Pito::Formatter

- [x] T2.1 Create `app/services/pito/formatter/release_date.rb` — `Pito::Formatter::ReleaseDate.call(game)` returning the precision-aware label (full date → `I18n.l(date, format: :long)` = "June 09, 2026"; month/quarter/year fallbacks; "TBA"). complexity: [low]
- [x] T2.2 Move the body of `Game#release_label` into the formatter; make `release_label` delegate to `Pito::Formatter::ReleaseDate.call(self)`. complexity: [low]
- [x] T2.3 Change the `:release_date` column `value:` proc in `list_columns.rb` to `->(g) { Pito::Formatter::ReleaseDate.call(g).to_s }`. complexity: [low]
- [x] T2.4 Create `spec/services/pito/formatter/release_date_spec.rb` covering full date "June 09, 2026", month-year, quarter, year-only, and TBA. complexity: [low]
- [x] T2.5 Run `bundle exec rspec` for the touched specs (incl. existing `Game#release_label` spec); `bin/rubocop` clean. complexity: [low]
- [x] T2.6 Commit: "Route release date through Pito::Formatter::ReleaseDate". complexity: [manual]

## Phase 3 — Wrapping multi-column table grid

- [x] T3.1 Add `.pito-data-grid` to `app/assets/tailwind/application.css`: base `display:grid; column-gap:0.5rem; row-gap:0.25rem;` + per-count rules `.pito-data-grid[data-cols="N"]` (N=2..8) where the first two columns are `max-content` and the rest are `repeat(N-2, minmax(0,1fr))` equally-spaced wrap-capable tracks. complexity: [low]
- [x] T3.2 Delete `SystemComponent#table_grid_cols`; add `table_col_count(n)` returning `[n,2].max` for the `data-cols` attribute (no inline style). complexity: [low]
- [x] T3.3 In `system_component.html.erb` (line ~111) replace the grid `class`/`<%= table_grid_cols %>` with `class="pito-data-grid<%= body ? ' mt-2 border-t border-line-default pt-2' : '' %>" data-cols="<%= table_col_count(n_cols) %>"`. complexity: [low]
- [x] T3.4 Apply the same replacement at the second grid site (line ~146, html branch). complexity: [low]
- [x] T3.5 Confirm non-`#` cells have no `whitespace-nowrap` so values wrap; leave heading cells nowrap (single-word headings). complexity: [low]
- [x] T3.6 Update `spec/components/pito/event/system_component_spec.rb` expectations that asserted the old `grid-cols-[…]`/`--pito-cols` → assert `pito-data-grid` + `data-cols="N"` and N spans. complexity: [low]
- [x] T3.7 Add an 8-column example (`#`, Game + 6 with-cols) asserting one `pito-data-grid` container, `data-cols="8"`, and 8 heading spans (no vertical-stack regression). complexity: [low]
- [x] T3.8 Run `bundle exec rspec spec/components`; `bin/rubocop` clean. complexity: [low]
- [x] T3.9 Commit: "Render list/data tables with a wrapping data-cols grid". complexity: [manual]

## Phase 4 — list games autocomplete: with connector + field tokens

(No noun-vocab reorder — bare `list ` "channels" default is intentional and untouched.)

- [x] T4.1 Extend `Pito::Suggestions::ListClauseGhost.ghost`: when registry present and no `with`/`sorted by` clause, add a connector branch that ghosts `with` after a completed noun (require noun + `\s+`; partial = last token; non-connector partials → no ghost). complexity: [high]
- [x] T4.2 In `suggestions_controller.js` `_computeLocalGhost`, after the chat-spec gate, `return null` when `chatSpec.name === "list"` so the client always defers the `list` verb to `POST /suggestions`. complexity: [low]
- [x] T4.3 Verify `_fetchDynamicGhost` applies `data.ghost.complete_current` (it does, line ~944) — no client ghost-apply change needed. complexity: [low]
- [x] T4.4 Add `list_clause_ghost_spec.rb` examples: `list games ` → ghost "with"; `list games w` → "ith"; `list games with ` → "platform"; `list games with d` → "eveloper"; `list games rpg` (filter partial) → no connector ghost. complexity: [low]
- [x] T4.5 Add `engine_spec.rb` example: `free_completions("list games ")` returns ghost "with" (server is the source of truth); confirm bare `list ` still ghosts "channels" (unchanged). complexity: [low]
- [x] T4.6 Add vitest cases to `spec/javascript/suggestions_controller.test.js`: typing `list games with ` defers to fetch and renders the mocked server ghost "platform"; `list games ` renders mocked "with"; assert the client does not locally resolve the `list` noun slot (defers instead). complexity: [high]
- [x] T4.7 Run `bundle exec rspec` (suggestions specs) and `npm test` (vitest); `bin/rubocop` clean; `node --check app/javascript/controllers/pito/suggestions_controller.js`. complexity: [low]
- [x] T4.8 Commit: "Drive list-games autocomplete from the server: with connector + field tokens". complexity: [manual]

## Phase 5 — Help message rewrite + `list games --help`

North star: the standard `help` message is a Standard (system) message with ONE
group for now — **GAMES** (yellow title) — containing a single kv-table row
`list games` → `use --help for more info`. And `list games --help` returns a
Standard message explaining the optional `with` columns and their aliases. **All
user-facing text comes from `Pito::Copy`** (`config/locales/pito/copy/en.yml` under
`pito.copy.*`). No inline style.

- [x] T5.1 Inspect `Pito::MessageBuilder::Help::FollowUpActions`, `Pito::Chat::Handlers::Help`, the `sections`/yellow rendering in `system_component.html.erb`, and the `Pito::Copy.render` API + copy-key layout. complexity: [low]
- [x] T5.2 Add `Pito::Copy` keys for the help message under `pito.copy.help.*` (`games_group_title` → "GAMES", `list_games_label` → "list games", `list_games_hint` → "use --help for more info"). complexity: [low]
- [x] T5.3 Rewrite `Pito::Chat::Handlers::Help#call` to use new `Pito::MessageBuilder::Help::Commands` — a visible `html: true` payload: yellow bold **GAMES** title + a kv-table row (`list games` → `use --help for more info`), all text via `Pito::Copy`. complexity: [high]
- [x] T5.4 Detect `--help` on the `list` verb: in `Pito::Chat::Handlers::List#call`, when `message.raw` matches `/(?:\A|\s)--help(?:\s|\z)/`, short-circuit to `games_list_help` instead of listing. complexity: [low]
- [x] T5.5 Add `Pito::Copy` keys (`pito.copy.list.games_help.*`) + `Pito::MessageBuilder::Game::ListHelp` building an "Option/Aliases" kv-table whose rows derive from `ListColumns::COLUMNS` (aliases stay in sync). complexity: [high]
- [x] T5.6 Specs: help handler renders a GAMES group + the `list games` row; `list games --help` returns the columns explanation (asserts each of the 6 columns appears); `list games` (no flag) still lists normally. complexity: [low]
- [x] T5.7 Run `bundle exec rspec` for the touched specs; `bin/rubocop` clean. complexity: [low]
- [x] T5.8 Commit: "Rewrite help message (GAMES group) + add list games --help columns guide". complexity: [manual]

## Phase 6 — Polish (post-review tweaks) + platform engine

Iterative refinements from live review. No inline style (data attributes only).

- [x] T6.1 Rework `list games --help` into an `nvim --help` man page (`Usage:` / `Options:` / `Columns:`, aligned token→description), drop the intro line + the Option/Aliases table. New `.pito-help-block` CSS + `pito.copy.list.games_help.*` keys. complexity: [high]
- [x] T6.2 Pluralize the list intro copy: "1 game" not "1 games" — `%{noun}` placeholder in all list_intro variants, builder passes `noun:`. complexity: [low]
- [x] T6.3 Right-align the `#` column heading (heading now a `{text,class:"text-right"}` cell; cells already right-aligned). complexity: [low]
- [x] T6.4 Right-align the Release + Year columns — headings (`heading_cells`) + row cells (`text-right`, year `tabular-nums`). complexity: [low]
- [x] T6.5 Release + Year as content-hugging trailing tracks (canonical order via `ListColumns.canonical_order`); others split `1fr`. `data-fixed-trailing` attribute + static CSS rules. complexity: [high]
- [x] T6.6 Centralized platform engine (`Pito::Game::PlatformTokens`): groups PS4/PS5→`ps`, Switch variants→`switch`, PC/Steam/GOG/Epic/Amazon/Battle.net→`steam`; single source that outputs labels or SVG (`icons_html`); enforces order **PS → Switch → Steam**. complexity: [high]
- [x] T6.7 SVGs moved to `public/platforms/{playstation,switch,steam}.svg`; logos render at ≤16px height via `.pito-platform-icon`; used in BOTH the list table (html cell) AND the detail card. complexity: [high]
- [x] T6.8 Specs for pluralization, alignment, fixed-width attribute, platform order, html-cell, and logo rendering. complexity: [low]
- [x] T6.9 Commit(s) per cohesive change. complexity: [manual]
- [x] T6.10 `/help` content: removed `ctrl+|`, `shift+r`, `esc`, backtick, and `space` from `pito.slash.help.keybindings`. complexity: [low]
- [x] T6.11 Bug: `Ctrl+Shift+R` (browser reload) no longer hijacked by the `shift+r` reply prefix (plain Shift+R only). complexity: [low]
- [x] T6.12 Bug: `list games --h` ghosts `elp` (`--help` added as a connector candidate). complexity: [low]
- [x] T6.13 Bug: `list games so` ghosts `rted by` (`sorted by` added to connector candidates). complexity: [low]
- [x] T6.14 Bug: TBA **sorting** — TBA (no date/year) now sorts AFTER all known dates ascending (and first descending) by treating unknown as the far future (`Date.new(9999,12,31)` / year `9999`) instead of `Date.new(0)`/`0`. Release stays **right-aligned** (correct). complexity: [low]
- [x] T6.15 `shift+tab`/`shift+space` cyclers wrapped in a focus-gated `filterHints` target (visible ⟺ focused); `m chat` hint is its inverse (visible ⟺ not focused) — mutually exclusive; dropped the leading separator before `m`. Shared `pito--chatbox-hints` controller covers `/` and `/not_found` via the same focus tracking. complexity: [high]

## Phase 7 — `--help` man page for every chat verb

North star: every chat verb supports `<verb> --help`, returning the SAME nvim/Linux
man-page format as `list games --help` (`Usage:` + `Arguments:`/`Options:` sections,
aliases included, `Columns:` only where a `with` clause exists). Typing `-` (or part
of `--help`) after a recognised verb ghosts `--help`. ALL copy from `Pito::Copy`.

Infra (shared, do first):
- [x] T7.1 Shared `Pito::MessageBuilder::ManPage.render(usage:, groups:)` renderer (extracted from `Game::ListHelp`, which now delegates to it — `list games --help` byte-identical). complexity: [high]
- [x] T7.2 `Pito::MessageBuilder::CommandHelp.call(verb:)` (:list→ListHelp; others read `pito.copy.chat_help.<verb>`) + dispatcher intercepts `/(?:\A|\s)--help(?:\s|\z)/` → CommandHelp. complexity: [high]
- [x] T7.3 Generic `--help` ghost hint: `-`/`--h` after a recognised verb ghosts `--help` (JS `_computeLocalGhost` + server `compute_ghost`; `list` via `ListClauseGhost`). complexity: [high]

Per-verb man pages (one atomic task each — author `pito.copy.chat_help.<verb>` + confirm the handler routes `--help`):
- [x] T7.4 `show --help` — copy added (`pito.copy.chat_help.show`); routes via dispatcher. complexity: [low]
- [x] T7.5 `find --help` — DROPPED. `find` is a grammar spec with NO handler (dead verb → `verb_not_implemented`); the speculative `chat_help.find` copy was removed. A dispatcher spec documents the `find`-has-no-handler behaviour. complexity: [high]
- [x] T7.6 `import --help` — copy added (accurate: `import <noun> [title]`, videos/game forms). complexity: [low]
- [x] T7.7 `sync --help` — copy added (all five sync sub-forms listed). complexity: [low]
- [x] T7.8 `footage --help` — copy added (`footage <title> <path>`). complexity: [low]
- [x] T7.9 `delete --help` — copy added. complexity: [low]
- [x] T7.10 `reindex --help` — copy added. complexity: [low]
- [x] T7.11 `publish --help` — copy added. complexity: [low]
- [x] T7.12 `unlist --help` — copy added. complexity: [low]
- [x] T7.13 `schedule --help` — copy added (`<title> <when>`, UTC time). complexity: [low]
- [x] T7.14 `link --help` — copy added (explains `game <ref> to video <ref>`). complexity: [low]
- [x] T7.15 `unlink --help` — copy added. complexity: [low]
- [x] T7.16 Specs: `ManPage` + `CommandHelp` (parametrized over all verbs) + dispatcher + `-`→`--help` ghost (Rails + vitest). complexity: [high]
- [x] T7.17 Commit(s) per cohesive change. complexity: [manual]

## Phase 8 — Per-noun `list --help`

`list <noun> --help` must be noun-aware (today it always shows the games man page).

- [x] T8.1 `list games --help` — games columns man page (done, Phase 5/6).
- [ ] T8.2 `list channels --help` — `Usage: list channels` + one random witty line from a ~50-variant `Pito::Copy` pool (no args: "there's nothing here" / "what did you expect?" / "found what you were looking for" tone).
- [ ] T8.3 `list videos --help` — games-style man page with the **video** columns: `game, games` / `duration` / `views` / `likes` / `comments` (copy from `Pito::Copy`).

## Phase 9 — `show game --help` / `show video --help`

Same man style. Each accepts a **title or an id** (id = the plain number, **no `#`**);
multi-word titles must be wrapped in `"…"`. (Implementation of `show` itself is known-bad
and will be revisited — these tasks are the `--help` man pages only.)

- [ ] T9.1 `show game --help` — `Usage: show game <title|id>`; accepts a game title (multi-word in `"…"`) or a game id (plain number). Copy from `Pito::Copy`.
- [ ] T9.2 `show video --help` — `Usage: show video <title|id>`; accepts a video title (multi-word in `"…"`) or a video id (plain number). Copy from `Pito::Copy`.

## Phase 10 — Fix `show game` / `show video` implementation

The real `show` behavior is currently wrong (hallucinated during earlier implementation).
These tasks fix the actual commands so they accept a title (multi-word in `"…"`) or a
plain id (no `#`) and resolve/show the right entity. Exact bugs to be specified when we
get here.

- [ ] T10.1 Fix `show game` implementation — title or plain id resolution + correct game detail render (details TBD on review).
- [ ] T10.2 Fix `show video` implementation — title or plain id resolution + correct video detail render (details TBD on review).

## Phase 11 — `import videos --help` / `import game --help`

Same man style. Copy from `Pito::Copy`.

- [ ] T11.1 `import videos --help` — `Usage: import videos [for @handle]`; explains: imports for ALL channels when shift+tab is `@all`, for the selected channel when shift+tab has one, or for `@handle` when `for @handle` is given.
- [ ] T11.2 `import game --help` — `Usage: import game [game title]`; explains: opens the IGDB import Sidebar with the title prefilled (if given) and runs an IGDB search.

## Phase 12 — Fix `import videos` / `import game` implementation

Real behavior is currently wrong (hallucinated). Fix to match the above.

- [ ] T12.1 Fix `import videos` — honor shift+tab scope (`@all` → all channels, selected channel → that one) and `for @handle` override.
- [ ] T12.2 Fix `import game` — open the Sidebar with the optional title prefilled and perform the IGDB search.

## Phase 13 — `sync videos --help` / `sync channels --help`

Same man style. Copy from `Pito::Copy`. The `with <items>` clause is a parsed comma-list
built to be extensible (today `videos`; future `analytics` for both forms).

- [ ] T13.1 `sync videos --help` — `Usage: sync videos [only id,id,id]`; scope = shift+tab channel (`@all` = all channels); `only` takes one or more **local numeric ids** (comma-separated, **no titles**). (Future: optional `with analytics` — not now.)
- [ ] T13.2 `sync channels --help` — `Usage: sync channels [with <items>]`; scope = shift+tab channel (`@all` = all channels); `with` is a comma-list of sync targets (today `videos`; future `analytics`) — e.g. `with videos`, `with videos,analytics`.

## Phase 14 — Rework `sync` implementation (drop `sync game` + legacy forms)

New `sync` = exactly two forms. **Drop completely** (code, specs, comments, copy,
confirmations): `sync game <ref>` (use `import game` to resync instead), the single
`sync video <ref>` path, and the hardcoded `sync channel` / `sync channel with videos`
forms.

- [ ] T14.1 `sync videos [only id,id,id]` — scope by shift+tab (`@all` = all channels); optional `only <ids>` = local numeric ids (comma-separated, no titles). Remove the old single-video path.
- [ ] T14.2 `sync channels [with <items>]` — scope by shift+tab (`@all` = all channels); optional `with <items>` parsed as a comma-list (today `videos`; **not hardcoded**, extensible to `analytics`). Remove the old hardcoded channel forms + `sync game`.

## Phase 15 — `footage game --help`

Same man style. Copy from `Pito::Copy`.

- [ ] T15.1 `footage game --help` — `Usage: footage game <id> <path>`; `<id>` = local game id (plain number, **no title**); `<path>` = local folder where the footage is stored.

## Phase 16 — Rework `footage game` implementation (id only, no title)

Current `footage <ref> <path>` accepts a title and uses a bare ref — not aligned. Rework to
the explicit `footage game <id> <path>` form: require a **local game id** (drop title ILIKE
resolution); keep the path. Drop misaligned code/specs/comments/copy per the global rule.

- [ ] T16.1 Rework `footage game <id> <path>` — resolve game by local id only (no title); keep the local footage path; drop the title-resolution path and align copy/specs.

## Phase 17 — `delete game --help` / `delete video --help`

Same man style. Copy from `Pito::Copy`. Both accept a **local id only** (plain number, no
`#`) — **never a title**. (Implementation rework to enforce id-only is deferred — `--help`
man pages only for now.)

- [ ] T17.1 `delete game --help` — `Usage: delete game <id>`; `<id>` = local game id (plain number, no title).
- [ ] T17.2 `delete video --help` — `Usage: delete video <id>`; `<id>` = local video id (plain number, no title).

## Phase 18 — Rework `delete game` / `delete video` implementation (id only)

Current `delete` accepts title or `#id` — not aligned. Rework to **local id only** (plain
number, never title). Drop title resolution + misaligned copy/specs per the global rule.

- [ ] T18.1 Rework `delete game <id>` — resolve by local id only (drop title); align copy/specs.
- [ ] T18.2 Rework `delete video <id>` — resolve by local id only (drop title); align copy/specs.

## Phase 19 — `reindex game --help` / `reindex video --help`

Same man style. Copy from `Pito::Copy`. Both accept a **local id only** (plain number, no
`#`) — **never a title**.

- [ ] T19.1 `reindex game --help` — `Usage: reindex game <id>`; `<id>` = local game id (re-embed in Voyage).
- [ ] T19.2 `reindex video --help` — `Usage: reindex video <id>`; `<id>` = local video id (re-embed in Voyage).

## Phase 20 — Rework `reindex game` / `reindex video` implementation (id only)

Rework to **local id only** (never title). Drop title resolution + misaligned copy/specs.

- [ ] T20.1 Rework `reindex game <id>` — resolve by local id only (drop title); align copy/specs.
- [ ] T20.2 Rework `reindex video <id>` — resolve by local id only (drop title); align copy/specs.

## Phase 21 — `publish` / `unlist` / `schedule` video `--help`

Same man style. Copy from `Pito::Copy`. All accept a **local video id only** (plain number,
no `#`) — **never a title**.

- [ ] T21.1 `publish video --help` — `Usage: publish video <id>`; `<id>` = local video id (sets YouTube visibility public).
- [ ] T21.2 `unlist video --help` — `Usage: unlist video <id>`; `<id>` = local video id (sets YouTube visibility unlisted).
- [ ] T21.3 `schedule video --help` — `Usage: schedule video <id> <date>`; `<id>` = local video id; `<date>` = `dd-mm-yyyy hh:mm`, **local time**, at least **30 min** from now.

## Phase 22 — Rework `publish` / `unlist` / `schedule` video implementation (id only)

Rework to **local video id only** (never title). Drop title resolution + misaligned
copy/specs per the global rule.

- [ ] T22.1 Rework `publish video <id>` — resolve by local id only; align copy/specs.
- [ ] T22.2 Rework `unlist video <id>` — resolve by local id only; align copy/specs.
- [ ] T22.3 Rework `schedule video <id> <date>` — local id only; date `dd-mm-yyyy hh:mm`, **local time**, ≥30 min from now. **Timezone:** date is in the given local time; if the channel timezone matches, scheduled time coincides — otherwise the agent must investigate the channel-timezone vs local-time mismatch and elaborate a solution. Align copy/specs.

## Phase 23 — `link`/`unlink` `game`/`video` `--help`

Same man style. Copy from `Pito::Copy`. Both sides are **local ids only** (plain numbers,
no `#`, never titles). `link` connector = `to`; `unlink` connector = `from`.

- [ ] T23.1 `link game --help` — `Usage: link game <id> to video <id>` (e.g. `link game 12 to video 32`).
- [ ] T23.2 `link video --help` — `Usage: link video <id> to game <id>`.
- [ ] T23.3 `unlink game --help` — `Usage: unlink game <id> from video <id>` (e.g. `unlink game 12 from video 32`).
- [ ] T23.4 `unlink video --help` — `Usage: unlink video <id> from game <id>`.

## Phase 24 — Rework `link` / `unlink` implementation (local ids only)

Current `link`/`unlink` take a free body (titles/refs) — not aligned. Rework to two-sided
**local-id** forms: `link game <id> to video <id>` / `link video <id> to game <id>`;
`unlink game <id> from video <id>` / `unlink video <id> from game <id>`. Drop title/ref
resolution + misaligned copy/specs per the global rule.

- [ ] T24.1 Rework `link` — parse `game <id> to video <id>` / `video <id> to game <id>` (local ids only); link the pair; align copy/specs.
- [ ] T24.2 Rework `unlink` — parse `game <id> from video <id>` / `video <id> from game <id>` (local ids only); unlink the pair; align copy/specs.

## Verification (end-to-end)

- `bundle exec rspec` green; `bin/rubocop` clean; `npm test` (vitest) green; `node --check` on the touched JS.
- Manual (via `/run` or dev server): in the shell type —
  - `list games` → clean 2-col table.
  - `list games with developer, publisher, genres, release date, year, platforms` → single wrapping table (not a vertical stack); Release reads "June 09, 2026"; Platform reads "PlayStation, Switch, Steam" with no Xbox/Google/Mac/PC.
  - Type `list games ` → ghost " with"; `list games with ` → ghost "platform"; cycle remaining field tokens; confirm "channels" never appears as a `with` field. (Bare `list ` still ghosts "channels" — intentional, unchanged.)
