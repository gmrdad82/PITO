# pito — System Architecture

## Topology

```
┌─────────────────────────────────────────────────┐
│  xterm.js web client          Rust Ratatui TUI  │
│  (browser)                    (kitty terminal)   │
│       │                            │            │
│       └──────────┬─────────────────┘            │
│                  │                              │
│          JSON API (Rails)                       │
│          /cable (WebSocket)                     │
│                  │                              │
│     ┌────────────┼────────────┐                │
│     │            │            │                 │
│  Postgres    Redis/      Meilisearch            │
│  +pgvector   Sidekiq     +Voyage AI             │
└─────────────────────────────────────────────────┘
```

## Clients

### xterm.js web client
- Served by Rails as a single-page terminal shell
- `app/views/layouts/application.html.erb` — sole ERB template
- `app/javascript/application.js` — xterm.js + @rails/actioncable
- esbuild bundles to `public/app.js`
- Subscribes to `StatusBarChannel` via Action Cable for live Sidekiq stats

### Rust TUI
- `extras/cli/` — Ratatui + crossterm
- `src/commands/tui.rs` — event loop, key handling
- `src/api/client.rs` — PitoClient trait (Dashboard data, channels, videos, auth, commands)
- `src/ui/mod.rs` — 5-zone terminal layout renderer
- Tokyo Night theme from `src/theme.rs`

### Both clients share
- 5-zone layout: header, main log, right sidebar, input line, status bar
- Command parity: `/help /status /channels /videos /games /reindex /config /auth`
- Keybindings from `config/keybindings.yml`
- Status bar via Action Cable WebSocket

## Rails API

JSON-only. No HTML views beyond the xterm.js shell. No ViewComponents, no
Turbo, no Stimulus, no Tailwind CSS, no Propshaft.

### Action Cable
- `Pito::CableBroadcaster` → `ActionCable.server.broadcast("pito:status_bar", payload)`
- `StatusBarBroadcastMiddleware` — Sidekiq middleware, fires after every job
- `StatusBarChannel` — streams from `pito:status_bar`
- Both clients subscribe: web via `@rails/actioncable`, Rust via WebSocket (coming)

### Key controllers
- `DashboardController` — index (JSON), status, sidebar
- `CommandsController` — POST /commands/execute
- `ImagesController` — game covers, video thumbnails
- `SessionsController` — TOTP login/logout

### Key services
- `Pito::CableBroadcaster` — status bar broadcast
- `Pito::Theme` — Tokyo Night palette, CSS/Rust export
- `Pito::Theme::Sections` — per-section color derivations
- `Pito::Transitions` — scramble/transition tokens
- `Pito::AssetsRoot` — filesystem path resolver for covers/thumbnails

## Models

### Core domain
- **Channel** — YouTube channel (channel_url, star, connected, last_synced_at)
- **Video** — YouTube video (youtube_video_id, channel, views, likes, watch_time)
- **Game** — IGDB game (title, release_date, cover art)
- **Footage** — raw video footage with frame extraction
- **Bundle** — game→channel recommendation pairing

### Supporting
- **ChannelDaily** — per-channel daily aggregate stats
- **VideoDaily** — per-video daily aggregate
- **CalendarEntry** — scheduled publish events
- **SavedView** — persisted filter queries
- **AppSetting** — singleton application settings (theme, notifications, timezone)

## Jobs

Sidekiq jobs at `app/jobs/` (flat namespace):
- `ChannelSync`, `VideoSync`, `GameSync` — data fetch from external APIs
- `MeilisearchReindexJob`, `VoyageReindexJob` — search index rebuild
- `StatusBarBroadcastMiddleware` — post-job cable broadcast
- `Pito::Test::SimpleSidekiqJob` — dummy job for status bar testing
- Various analytics sync jobs

## Status bar pipeline

```
Sidekiq job executes
  → StatusBarBroadcastMiddleware (ensure block)
  → SidekiqStatusPayload.call (reads Sidekiq::Stats)
  → Pito::CableBroadcaster.broadcast_status_bar(payload)
  → ActionCable.server.broadcast("pito:status_bar", payload)
  → StatusBarChannel (stream_from "pito:status_bar")
  → Web client: cable.subscriptions.received → update HTML #sb-* elements
  → Rust TUI: WebSocket receive → update status struct → render
```
