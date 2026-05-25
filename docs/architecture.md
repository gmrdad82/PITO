# Architecture

## System topology

pito is a single Rails monolith with two companion clients. Hosted
locally on the owner's laptop, exposed via cloudflared tunnels.

- **app.pitomd.com** — Rails Puma serving the primary web surface
- **mcp.pitomd.com** — separate Rails Puma serving the MCP HTTP transport
  (parked; future revisit)
- **pitomd.com** — Astro static landing page on Cloudflare Pages

Companion clients:

- **`pito` CLI** at `extras/cli/` — Rust + Ratatui. Default mode is the
  TUI. CLI implements 100% of what the web app does. Subcommands handle
  footage upload (`pito footage`) + helpers (`pito help`, `pito version`).
- **Astro website** at `extras/website/`.

Future deployment target: Hetzner via Kamal.

## Tech stack

- Rails 8.1 with Hotwire (Turbo + Stimulus)
- Postgres 17 + pgvector + pgcrypto + citext (Docker)
- Redis 7 (Docker) — Sidekiq queue + Rails cache
- Sidekiq + sidekiq-cron
- Meilisearch — keyword search
- Voyage AI — embeddings
- RSpec + FactoryBot + Faker + Shoulda Matchers + WebMock
- ViewComponent for HTML
- MCP via the `mcp` gem
- Rust + Ratatui for the `pito` CLI
- Astro 4 for the Cloudflare Pages landing

## Layout

```
.
├── app/, bin/, config/, db/, public/, spec/, vendor/   # Rails at root
├── lib/                                                 # Rails-only library
├── extras/
│   ├── cli/                                             # Rust binary
│   └── website/                                         # Astro landing
├── docs/                                                # canonical docs
├── .claude-config/                                      # agent definitions
└── tmp/                                                 # demo HTMLs (gitignored)
```

## Commands

```
bin/setup            # install deps, start Docker, prepare DB
bin/dev              # Docker + Puma + Sidekiq + Tailwind watcher
bin/mcp              # MCP stdio server
bin/mcp-web          # MCP HTTP server on :3001
bin/test             # fast spec loop (system specs excluded — no Capybara)
bin/test failed      # re-run only failures from the last run
bin/test path/...    # focused spec run
bundle exec rubocop  # lint
```

## Authentication (2026-05-25)

### Single-user model

No `User` model. No password. pito has exactly one owner. TOTP seed and
enrollment timestamp live on the `AppSetting` singleton row
(`totp_seed`, `totp_enrolled_at`). `Current.session` carries the live
session; `Current.user` is gone.

### Login flow

- `GET /` always serves the root layout (no redirect to `/login`).
- When `Current.session.nil?`, an **auth dialog** overlays the root — a
  `Tui::AuthDialogComponent` rendered in the layout. No dedicated login
  page exists.
- The user enters a 6-digit TOTP code, or toggles to backup-code mode
  and enters an 8-character backup code.
- `POST /login` → `SessionsController#create` verifies via:
  - `Pito::Auth::TotpVerifier` (reads `AppSetting.totp_seed`)
  - `Pito::Auth::BackupCodeConsumer` (consumes one stored backup code)
- On success: `Session` row created, opaque cookie set, page reload.
  Panels hydrate; cable subscriptions begin.
- On failure: 422 with a generic "login failed" message (no code leak).

### Enrollment

Rake-only. No web UI.

```
bin/rails pito:auth:enroll
```

Prints the `otpauth://` URI, an ASCII QR code for any authenticator app,
and 10 backup codes (stored as HMAC-SHA256 digests in `AppSetting`).
Re-running re-seeds — prior backup codes are invalidated.

### Wire format (TUI / CLI)

`POST /login` accepts `application/x-www-form-urlencoded`:

- TOTP path: `code=<6-digit>`
- Backup path: `backup_code=<8-char>`

Response:

- `302` redirect on success (session cookie set in `Set-Cookie`).
- `422` with a generic "login failed" body on failure.

Session cookie is an opaque token. The `Session` row stores the
HMAC-SHA256 digest — the raw token is never persisted.

### YouTube channel access

OAuth2 per channel. `client_id` + `client_secret` in
`Rails.application.credentials.google_oauth`. Each `Channel` row has a
nullable FK to `youtube_connections`.

### Dropped in this sweep (2026-05-25)

- `User` model (username, password\_digest, totp\_secret, last\_login\_at)
- `AuthAuditLog` model
- `Compositable` concern
- `Login::TotpChallengesController`
- `Settings::Security::TotpsController`
- Mandatory-2FA gate
- Password handling
- `Pito::SyncState` service
- `master_sync_paused` `AppSetting` column
- `:pause_target` / `:resume_target` / `:toggle_master_sync` action bus entries
- Space `p` leader binding
- Sync-pause help group

## Datastore

- **Postgres 17** — primary store. Single-install, single-owner — no
  `tenant_id` columns. The authenticated session has full read/write access.
- **pgvector** — embedding storage for Voyage-AI-vectorized fields.
- **pgcrypto** — column-level encryption via Rails 8 active record
  encryption.
- **citext** — case-insensitive text (retained for future use; `users`
  table dropped).
- **Redis 7** — Sidekiq queue + Rails cache.
- **Meilisearch** — keyword search.
- **Filesystem volume:**
  - `/assets` — game cover art, bundle compound cover art, future video
    thumbnails

(`/notes` volume removed per the Notes drop.)

## Models

### Session

Issued per login. Columns:

- `id`, `token_digest` (HMAC-SHA256 of the opaque cookie token),
  `last_seen_at`, `ip` (inet), `device`, `browser`,
  `created_at`, `updated_at`

No `user_id` FK — there is only one owner. `User` model dropped.

### Channel

Read-only mirror from YouTube. URL locked after create. Columns:

- `id`, `channel_url` (locked after create), `star`, `handle`, `name`,
  `description`, `keywords`, `summary_embedding` (pgvector),
  `last_synced_at`, `youtube_connection_id`

`Channel#genre` is derived from videos' category + subcategory.

### Video

Belongs to one channel. Many-to-many with games. Editable in pito:
title, description, thumbnail, playlist, visibility. Carries embedding +
analytics rollup associations.

### Game

Sourced from IGDB plus owner-added fields:

- `igdb_id`, IGDB-mirrored fields (name, summary, cover, release dates,
  platforms, genres, etc.)
- Owner-added: `owned`, `played`
- `summary_embedding` (pgvector)

Many-to-many with bundles. Many-to-many with videos. Has many footage
(direct association — no Project intermediary).

### Bundle

A group of games. `name`, `slug`, `composite_cover_checksum`,
`summary_embedding`. Cover compound generated from member games' cover
art via `Bundle::Composite::*`.

### Footage

Captured material associated with a game. Columns:

- `hdr_or_sdr`, `fps`, `resolution`, `duration`, `source`
  (camera | obs), `aspect_ratio`, `orientation`, `recorded_at`
- `game_id` (direct FK; max one game per footage; nullable for non-game
  footage)

CLI uploads footage metadata from a local path to a game.

### AppSetting

Singleton-style settings table for non-secret runtime flags
(theme, indexing toggles, timezone, notifications toggles, reindex
running state).

### NotificationDeliveryChannel

Discord + Slack webhook URLs (one row each).

### Dropped

- **`Project`** model dropped. Footage attaches to Game directly.
- **`Note`** model dropped (+ `/notes` filesystem volume + embedding +
  search index entries).

## Action bus

Every user-triggerable action — web click, `:` command palette, leader
menu, MCP tool call, CLI subcommand — flows through one registry.

```ruby
# config/initializers/pito_actions.rb
Pito::ActionRegistry.define(:reindex_meilisearch,
  path:         -> { settings_stack_meilisearch_reindex_path },
  method:       :post,
  confirmation: { brand: "Meilisearch", danger: true },
  i18n_key:     "tui.commands.reindex_meilisearch",
  cable_panel:  "pito:settings:stack:meilisearch")
```

**JS dispatcher:** `window.Pito.dispatchAction(name)` reads
`<meta name="pito-actions">` (registry JSON shipped to the browser at
layout render), opens the canonical confirmation dialog if the action
has `confirmation:`, then POSTs via Turbo form. Expects `204 no_content`
— cable handles all UI updates.

**Ruby dispatcher:** `Pito::ActionDispatcher` — same flow for MCP / CLI
callers (in-process). Symmetric to the JS dispatcher so any client uses
one entry point per stack.

**Stimulus controller:** `action-trigger`
(`data-controller="action-trigger" data-action="click->action-trigger#dispatch"
data-action-name="<key>"`). Used by `Tui::ActionButtonComponent` — the
canonical bracketed-button VC.

## Cable channels

| Channel | Scope | Subscribers | Payload kinds |
|---|---|---|---|
| `pito:status_bar` | Global | TST controller | `data` (`{sync_state, workers, sidekiq{b,e,r,s,d}, clock}`) |
| `pito:<screen>:<panel>` | Panel | Panel VC via `turbo_stream_from` | panel-specific |
| `pito:<screen>:<panel>:<sub_panel>` | Sub-panel | Sub-panel VC | sub-panel-specific |

**Subscription on paint:** every panel VC subscribes to its own stream
when rendered. Re-renders re-subscribe automatically.

**Broadcasts:**

- `StatusBarBroadcastMiddleware` (Sidekiq middleware) fires START + END
  for every Sidekiq job → `pito:status_bar`.
- `StatusBarBroadcastJob` — trailing-edge ~1s after each Sidekiq job to
  repaint with accurate worker count.
- `Pito::CableBroadcaster.broadcast_panel(channel, kind:, payload:)` —
  canonical panel-scoped emitter used by job code.

**Envelope:** `{ kind: <string>, payload: <hash>, ts: <ISO8601> }`.

## Sync indicator (2026-05-25)

Visual-only indicator in the TST (top status area). Reports cable
activity state to the owner. No pause, no toggle, no master switch.

### States (3 only)

| State | Style | Meaning |
|---|---|---|
| `synced` | muted | Cable connected; no in-flight activity |
| `syncing` | accent + shimmer | Cable active (panel broadcast, sub-panel broadcast, or Sidekiq stats in flight) |
| `disconnected` | danger (red) | Cable disconnected event received |

### Timing

- `syncing` triggers on any cable activity on any panel, sub-panel, or
  `pito:status_bar` stream.
- `synced` returns 300 ms after the last activity (trailing-edge debounce).
- `disconnected` triggers immediately on a cable disconnect event.
  Clears to `synced` on reconnect.

### Placement

Single instance in the TST only. Not repeated in panels or sub-panels.
No click handler. No interactivity.

### Client

`tui_sync_indicator_controller.js` — listens to cable activity events
bridged via `pito_sync_state_bridge.js`. Paints the indicator via direct
`textContent` / class swap. No localStorage. No POSTs.

### Dropped

`Pito::SyncState`, `SyncController`, `POST /sync/toggle`, the
`sync.app` / `sync.<panel>` `AppSetting` keys, master-toggle Space `p`
binding, and all cascade / suppression logic are removed.

## Background jobs

- **Sidekiq** with sidekiq-cron for schedules.
- **Locking** — long-running / non-idempotent jobs acquire a Sidekiq lock
  (e.g., `MeilisearchReindexJob`, `VoyageReindexJob`, `Channel::SyncJob`).
  Two instances of the same job cannot run in parallel.
- **CRON jobs** — schedule defined in `config/sidekiq_cron.yml`.

## Canonical namespace taxonomy

See `CLAUDE.md` § Canonical namespace policy for the full taxonomy.
Summary:

### Cross-cutting (`Pito::*`) — default for non-domain, non-screen

`Pito::ActionRegistry`, `Pito::ActionDispatcher`, `Pito::CableBroadcaster`,
`Pito::Theme` (incl. `Pito::Theme::Sections`), `Pito::GitRevision`,
`Pito::Auth::*`, `Pito::Formatter::*`, `Pito::Notifications::*`,
`Pito::Search::*` (Engine, Omnisearch, Everywhere), `Pito::Calendar::*`,
`Pito::Analytics::*` (primitives: DataFreshness, WindowSummary,
Backfill, TimeBucketAggregator), `Pito::Recommendation::*` (primitives:
VectorSimilarity, TopK, HmsScorer, WeightedBlend),
`Pito::ExternalApiTracker::*` (Youtube, Igdb, Voyage),
`Pito::Schedule::Conflict`, `Pito::SlugBuilder`, `Pito::TimeZone`, etc.

**`Pito::Transitions`** — canonical transition tokens + effect registry.
Ruby-first. Exports to CSS custom properties + Rust `theme.rs` (mirrors
the `Pito::Theme` pattern). Single source of truth for durations,
easings, frame counts, debounce.

- `Pito::Transitions::Tokens` — duration / stagger / easing / debounce
  constants (see `docs/design.md` § Transitions § Token contract).
- `Pito::Transitions::Effects` — the 2 canonical effects
  (`scramble-settle`, `color-crossfade`) as a frozen map. New effects
  require an explicit registry entry + parity spec — no silent
  additions.
- `Pito::Transitions::ReducedMotion` — the global gate honoring
  `prefers-reduced-motion: reduce`.

Companion JS: `app/javascript/controllers/tui_transition_controller.js`
— the single Stimulus controller that drives all transitions via
data-attrs. VCs opt in via the helper module `Tui::Transitionable`
(emits the canonical data-attr set so no VC types raw attrs). The
`shimmer` decoration is NOT a transition and is not registered here —
it lives on `Tui::SyncIndicatorComponent` only, gated by `syncing`
state.

### Home services live under `Pito::*`

Home is not a domain — it's the dashboard + system-monitoring surface.
No `Home::*` namespace. Home's services live under `Pito::*` (same
namespace as cross-cutting infrastructure). Ex-settings services
(`Pito::Stack::HealthState`, etc.) live here.

`Settings::*` is gone for good (Settings screen + namespace both
dropped).

### Domain layer (singular)

**`Channel::*`** — `Channel::Youtube::*`, `Channel::Analytics::*`,
`Channel::GameRecommendation`, `Channel::BundleRecommendation`,
`Channel::VoyageIndexer`, `Channel::MeilisearchIndexer`

**`Video::*`** — `Video::Analytics::*`, `Video::ThumbnailPreview`,
`Video::DiffComputer`, `Video::PublishWorkflow`

**`Game::*`** — `Game::Igdb::*`, `Game::ChannelRecommendation`,
`Game::BundleRecommendation`, `Game::SimilarGames`, `Game::VoyageIndexer`,
`Game::MeilisearchIndexer`

**`Bundle::*`** — `Bundle::Composite::*` (cover composite),
`Bundle::ChannelRecommendation`, `Bundle::SuggestedFor`,
`Bundle::VoyageIndexer`, `Bundle::MeilisearchIndexer`

**`Footage::*`** — `Footage::FrameExtractor`, `Footage::Cache`

### Screen layer

Three screens. Panel-as-VC per `CLAUDE.md`:

- **Home (`/`)** → `Pito::*PanelComponent` (no `Screen::Home::` wrapper)
- **Videos (`/videos`)** → `Screen::Videos::*PanelComponent`
- **Games (`/games`)** → `Screen::Games::*PanelComponent`

### UI primitive layer

`Tui::*` — checkbox, dialog, palette, sortable header, charts, etc.

## Recommendation layer (bidirectional)

Pattern: `<Subject>::<Object>Recommendation`. Each direction is a
separate service because the question + algorithm differ.

| Service | Question | Input | Output |
|---|---|---|---|
| `Game::ChannelRecommendation` | "Which channels should cover this game?" | Game | List of Channels (ranked) |
| `Channel::GameRecommendation` | "Which games should this channel cover?" | Channel | List of Games (ranked) |
| `Bundle::ChannelRecommendation` | "Which channels would best cover this bundle?" | Bundle | List of Channels |
| `Channel::BundleRecommendation` | "Which bundles should this channel consider?" | Channel | List of Bundles |
| `Game::BundleRecommendation` | "Which bundles include this game (ranked)?" | Game | List of Bundles |

Shared primitives under `Pito::Recommendation::*`:
`VectorSimilarity` (cosine over Voyage embeddings), `TopK` (ranking
with score thresholds), `HmsScorer` (Heat Map Score: hard-stop color
buckets), `WeightedBlend` (combine multiple ranking signals).

## Three-layer analytics

| Layer | Namespace | Purpose | Examples |
|---|---|---|---|
| Primitives | `Pito::Analytics::*` | Cross-cutting: freshness, window aggregation, time-bucket rollups, backfill | `Pito::Analytics::DataFreshness`, `Pito::Analytics::WindowSummary`, `Pito::Analytics::Backfill`, `Pito::Analytics::TimeBucketAggregator` |
| Channel analytics | `Channel::Analytics::*` | Channel-specific queries / rollups | `Channel::Analytics::DailyRollup`, `Channel::Analytics::DemographicsBucket`, `Channel::Analytics::TrafficSourcesSummary` |
| Video analytics | `Video::Analytics::*` | Video-specific queries / rollups | `Video::Analytics::RetentionCurve`, `Video::Analytics::EndScreenStats`, `Video::Analytics::ViewerTimeBuckets` |

MCP exposes the domain layer (`Channel::Analytics::*` +
`Video::Analytics::*`); primitives stay infrastructure.

## ViewComponent architecture

Every visible HTML structure is a `ViewComponent`. Each:

1. `.rb` class file
2. `.html.erb` template
3. Spec at `spec/components/<path>/<name>_component_spec.rb`
4. Class-level docblock header documenting kwargs, variants,
   focusables, mode behavior, cable subscriptions, related dependencies
   (for TUI re-derivation)

Data transformations live in `Pito::Formatter::*` under
`app/services/pito/formatter/`.

Helpers reserved for single-purpose pure logic. Partials allowed only
for ≤ 5 lines of static markup with no parameter-driven branching.

## Panel-as-ViewComponent

Every panel = one VC under `Screen::<screen>::<name>PanelComponent`.

Each Panel VC owns:

- `focusables` method (ordered Ruby array of `{key:, style:}`)
- `CABLE_CHANNEL` constant (e.g., `"pito:settings:security"`)
- `keybinds` method (panel-local; i18n-resolved for TUI sharing)
- Sub-panel VC composition (explicit `<%= render Screen::...::SubPanelComponent.new(...) %>`)
- Data fetched in `initialize` / `before_render` via domain / screen
  services

This makes the panel-by-name discoverability the user expects: open the
file, see the data sources, see the cable channel, see the keybinds.

## Turbo + cable per panel

- Every form is Turbo-default. Never `data-turbo="false"`.
- Panel-scoped controller actions return `head :no_content` /
  `render turbo_stream:` / `turbo_frame:`. Never `redirect_to`.
- Each panel ViewComponent subscribes to its own
  `pito:<screen>:<panel>` stream.

Page navigation is initial paint only; after that, every panel update
flows through cable broadcasts.

## UI architecture rules

### Never use localStorage for state

Persistent UI state lives in `AppSetting` / DB. The server renders
truth; JS submits `POST` and listens to cable broadcasts. localStorage
is forbidden for any state that must survive a page reload or sync
across clients.

### No URL-hash sorting on tables

Sort state lives in URL query params (server-readable). The server picks
defaults when params are unset and renders the V4 underline indicator on
first paint. No client-only sort state.

### All actions are section accent

Every bracketed action (`[reindex]`, `[ ] sync`, `[update]`, etc.) paints
in `var(--section-accent)`. Exception: `[!] sync` in a disconnected
state renders red (`var(--red)`).

### Text-color taxonomy

| Text class | Color |
|---|---|
| Data values | white |
| Labels | muted |
| Titles + actions | accent |

### Stack sub-panels are a 2x2 50/50 grid

The Stack panel on Home lays out its four sub-panels (Meilisearch /
Voyage AI / Postgres / Assets) in a two-column, two-row grid where each
cell takes exactly 50% of the available width.

### Bracket-to-space rule on TST chrome

Non-action labels adjacent to bracketed actions on the TST chrome use
literal spaces as separators, not brackets. Brackets are reserved for
interactive actions only.

## Deployment

- **Now:** local on owner's laptop + cloudflared tunnels.
- **Soon:** GitHub Actions for CI (2000 credits/month; `[skipci]`
  default; user signals "unblocked" when CI should run).
- **Eventually:** Hetzner box, Kamal-deployed Docker.
