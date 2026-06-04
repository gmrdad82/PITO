# pito — Follow-ups (post-Beta)

Work intentionally **deferred** out of the Beta reboot (Plan 4). These were moved
here so Plan 4 contains only what ships in the Beta. Pick these up after merge.

> Source: split out of `docs/plan-beta-reboot-04-consolidation.md`. Phase numbers
> are kept for traceability; renumber when this becomes its own plan.

---

## A. Videos pipeline (deferred — P31–P34)

### P31 — `/import videos` (smart incremental pull)

> Pull YouTube → `Video` (read-only mirror). Quota-aware. Channel from TAB; period is dead data (carried only).

- [ ] T31.1 `/import videos` handler reads the selected channels (TAB). (Period is carried but unused.) complexity: [low]
- [ ] T31.2 `@all` → one `ImportVideosJob` per channel; single channel → one. complexity: [low]
- [ ] T31.3 Per job: persist + broadcast a per-channel progress Segment. complexity: [low]
- [ ] T31.4 Progress Segment payload updated via Turbo Stream replace (targets its DOM id). complexity: [high]
- [ ] T31.5 `ImportVideosJob` walks the channel's uploads playlist newest-first (`playlistItems.list`), paginating. complexity: [high]
- [ ] T31.6 Batch `videos.list` only for new/changed ids; compare stored `etag`/checksum; skip unchanged. complexity: [high]
- [ ] T31.7 Stop paging after a run of K consecutive known-unchanged videos (incremental tail cutoff). complexity: [high]
- [ ] T31.8 Upsert `Video` (dedupe by `youtube_video_id`); store `etag` + `last_synced_at`. complexity: [low]
- [ ] T31.9 Update the progress Segment; summary (N new / M updated / skipped) on finish. complexity: [low]
- [ ] T31.10 Specs (stubbed API; incremental stop; checksum skip; dedupe; progress). complexity: [high]
- [ ] T31.11 Smoke: `@all` → multiple Segments; single → one. complexity: [manual]
- [ ] T31.12 Commit: `/import videos: smart incremental pull`. complexity: [manual]

### P32 — VideoPreview model + edit UI

> Stage edits without touching `Video`. Full edit experience.

- [ ] T32.1 Confirm the `VideoPreview` model + `has_one_attached :thumbnail`. complexity: [low]
- [ ] T32.2 Edit surface: `/edit video <id>` opens the edit form (or `/edit video` with no id opens the video picker, reusing P34's). complexity: [high]
- [ ] T32.3 Form fields (YouTube Studio parity): title, description, tags, category + game title, made-for-kids, paid promotion, AI/altered-content, allow embedding, automatic chapters/places/concepts, notify subscribers, Shorts remixing, thumbnail upload (Active Storage). complexity: [high]
- [ ] T32.4 Save creates/updates a `VideoPreview` (status `draft`); never mutates `Video`. complexity: [low]
- [ ] T32.5 Show a diff/preview of the draft vs current `Video` values. complexity: [high]
- [ ] T32.6 Thumbnail preview render. complexity: [low]
- [ ] T32.7 Stimulus for the form (keyboard + mouse). complexity: [high]
- [ ] T32.8 i18n all copy. complexity: [low]
- [ ] T32.9 Model/component/request specs. complexity: [low]
- [ ] T32.10 Smoke: compose a preview; persists as draft; `Video` unchanged. complexity: [manual]
- [ ] T32.11 Commit: `VideoPreview model + edit UI`. complexity: [manual]

### P33 — `/update videos` (publish previews → re-import)

> Push pending VideoPreviews to YouTube; on success re-import that video.

- [ ] T33.1 `/update videos` handler reads channels + period; collects pending (`draft`) previews in scope. complexity: [low]
- [ ] T33.2 Per channel → one `PublishPreviewsJob` + one progress Segment (reuse P31's fan-out). complexity: [low]
- [ ] T33.3 Job maps preview → **API-supported fields** and publishes (`videos.update` snippet/status + `thumbnails.set`); flags staged Studio-only fields as not-published; status `publishing` → `published`/`failed`. complexity: [high]
- [ ] T33.4 On each success → enqueue a single-video `ImportVideosJob` to refresh `Video`. complexity: [low]
- [ ] T33.5 On failure → mark `failed` + surface the error in the Segment. complexity: [low]
- [ ] T33.6 Progress Segment updates; summary on finish. complexity: [low]
- [ ] T33.7 Specs (stubbed API; publish → reimport enqueued; failure path). complexity: [high]
- [ ] T33.8 Smoke. complexity: [manual]
- [ ] T33.9 Commit: `/update videos: publish previews → re-import`. complexity: [manual]

### P34 — Video lifecycle (`/publish` `/schedule` `/unlist` `/delete`)

> Each command opens a **sidebar picker** of eligible videos → select → echo + async job → Braille → result Segment **with a link to the video**.

- [ ] T34.1 Shared video-picker sidebar (reuse the `Pito::Sidebar` picker pattern). complexity: [high]
- [ ] T34.2 `/publish` → picker of publishable videos (private/draft, unlisted, scheduled). complexity: [low]
- [ ] T34.3 On select → set privacy `public` (`videos.update`). complexity: [high]
- [ ] T34.4 `/schedule` → same picker + a **date step** → privacy `private` + `status.publishAt`. complexity: [high]
- [ ] T34.5 `/unlist` → picker of public/unlisted → privacy `unlisted`. complexity: [low]
- [ ] T34.6 After publish/schedule/unlist → enqueue a single-video import. complexity: [low]
- [ ] T34.7 `/delete` → picker → `confirmation` Segment → `videos.delete`. complexity: [high]
- [ ] T34.8 On delete success → remove the local `Video` (+ dependents). complexity: [low]
- [ ] T34.9 Common flow: echo + async job → Braille → result Segment with a video link. complexity: [low]
- [ ] T34.10 Specs (eligible-set per command; stubbed state changes; schedule date; delete confirm). complexity: [high]
- [ ] T34.11 Smoke each command. complexity: [manual]
- [ ] T34.12 Commit: `Video lifecycle via picker (publish/schedule/unlist/delete)`. complexity: [manual]

---

## B. Games pipeline (deferred — P35–P38)

### P35 — Re-wire IGDB services

> Backend mostly in tree (`game/igdb/*`, `game/search_service`, `pito/search/search_games`, jobs).

- [ ] T35.1 Verify IGDB credentials path (`Game::Igdb::TokenCache` / AppSetting / credentials). complexity: [low]
- [ ] T35.2 Smoke `Game::Igdb` client search (or stubbed spec). complexity: [high]
- [ ] T35.3 Confirm `Game::Igdb::SyncGame` populates a Game + recompute `score`. complexity: [high]
- [ ] T35.4 Confirm `Game::SearchService` / `Pito::Search::SearchGames` work. complexity: [low]
- [ ] T35.5 Add/fix specs (WebMock stubbed IGDB). complexity: [low]
- [ ] T35.6 Commit: `Re-wire + verify IGDB search/sync services`. complexity: [manual]

### P36 — `/add game` + sidebar search UI

> Rebuild the dropped search UI as a sidebar. Adds to the global game library.

- [ ] T36.1 `/add game` opens the sidebar in "game search" mode. complexity: [low]
- [ ] T36.2 Sidebar search box; min-char gate; debounce. complexity: [low]
- [ ] T36.3 Search endpoint returns IGDB matches (+ flag already-in-DB). complexity: [high]
- [ ] T36.4 Render results; in-DB rows get a marker. complexity: [low]
- [ ] T36.5 Keyboard nav (↑/↓ + Enter) + mouse click. complexity: [high]
- [ ] T36.6 Selecting a result shows its game details in the sidebar. complexity: [high]
- [ ] T36.7 Reuse `Pito::Sidebar::*`; i18n all copy. complexity: [low]
- [ ] T36.8 Component/request specs. complexity: [low]
- [ ] T36.9 Smoke. complexity: [manual]
- [ ] T36.10 Commit: `/add game sidebar search UI`. complexity: [manual]

### P37 — Add → async sync-once

- [ ] T37.1 "Add" creates a Game stub from the IGDB result (igdb_id, title). complexity: [low]
- [ ] T37.2 Enqueue `GameIgdbSync(game)` **once** (full details + score + Voyage index). complexity: [low]
- [ ] T37.3 Dedupe: adding an already-in-DB game is a no-op. complexity: [low]
- [ ] T37.4 Confirmation Segment / sidebar update on completion. complexity: [low]
- [ ] T37.5 Job spec. complexity: [low]
- [ ] T37.6 Smoke. complexity: [manual]
- [ ] T37.7 Commit: `Add game → async one-shot IGDB sync`. complexity: [manual]

### P38 — Daily unreleased-games refresh

- [ ] T38.1 Confirm `game_igdb_nightly_refresh.rb`; scope to **not-yet-released** games. complexity: [high]
- [ ] T38.2 Register as a recurring daily job (SolidQueue `config/recurring.yml`). complexity: [low]
- [ ] T38.3 On refresh: re-sync release info + recompute `score`; stop once released. complexity: [low]
- [ ] T38.4 Job spec. complexity: [low]
- [ ] T38.5 Smoke. complexity: [manual]
- [ ] T38.6 Commit: `Daily refresh for unreleased games`. complexity: [manual]

---

## C. AGENTS.md conventions (deferred — P43)

> Document the conventions established across the reboot. Do once the video/game
> pipelines land (several sections describe them).

- [ ] T43.1 `## Auth` — cookie session (24h idle, no hard max), no Session model, TOTP retained. complexity: [low]
- [ ] T43.2 `## Factories` — every model; `factories_spec` auto-validates. complexity: [low]
- [ ] T43.3 `## Rake` — `pito:test:*` / `pito:tools:*`; seeds prepare/populate; specced. complexity: [low]
- [ ] T43.4 `## Component CSS` — `data-accent`; no inline `style=`; **extract components, no spaghetti** (see InlineSeparator/Shortcut/Hint/Filter precedent). complexity: [low]
- [ ] T43.5 `## Footage / ffprobe` — Probe, `pito:tools:probe`, needs_grading/orientation. complexity: [low]
- [ ] T43.6 `## Dispatch` — async, persist-before-broadcast, turn timing, backend elapsed, command context. complexity: [low]
- [ ] T43.7 `## Conversations` — uuid routing, naming, sidebar grouping, `/new`/`/resume`, rename, history (↑/↓), localStorage panel persistence, cross-instance cable sync. complexity: [low]
- [ ] T43.8 `## Chatbox` — TAB channels, Shift+TAB periods (dead), thinking indicator + dictionaries, autocomplete (palette + ghost), typing phase-in, typewriter reveal. complexity: [low]
- [ ] T43.9 `## Videos` — read-only mirror; `/import`; `VideoPreview` + `/edit video`; `/update`; lifecycle. complexity: [low]
- [ ] T43.10 `## Games` — IGDB search sidebar, `/add game`, async sync, nightly refresh. complexity: [low]
- [ ] T43.11 `## Notifications` — model, `ctrl+/` sidebar, daily cleanup job, cross-instance sync. complexity: [low]
- [ ] T43.12 `## Analytics namespaces` — `Pito::Stats` vs `Pito::Analytics` (directional). complexity: [low]
- [ ] T43.13 Commit: `AGENTS.md conventions`. complexity: [manual]

---

## D. Playlists (future — full management)

> **Dropped for the Beta** — no `Playlist` model in the DB yet. Confirmed feasible
> via the **YouTube Data API v3** (all five requested operations are supported):
>
> 1. **Create a playlist** — `playlists.insert` (snippet.title/description). ✅
> 2. **Add a video** — `playlistItems.insert` (snippet.playlistId + resourceId.videoId). ✅
> 3. **Remove a video** — `playlistItems.delete` (by playlistItem id). ✅
> 4. **Public / private** — `playlists.insert`/`playlists.update` `status.privacyStatus` (`public` | `unlisted` | `private`). ✅
> 5. **Order** — each item has `snippet.position`; set on insert and reorder via `playlistItems.update` with a new `position`. ✅
>
> Quota note: writes cost ~50 units each (insert/update/delete); a full reorder of N items is N updates — batch/debounce.

- [ ] PL.1 `Playlist` + `PlaylistItem` models (mirror YouTube ids; `privacy_status`; item `position`; `dependent: :destroy`). complexity: [high]
- [ ] PL.2 `Channel::Youtube::Client` playlist methods: `create_playlist`, `update_playlist`, `list_playlists`, `insert_item`, `delete_item`, `update_item_position`. complexity: [high]
- [ ] PL.3 `/playlist new <title> [public|private|unlisted]` → create on YouTube + mirror. complexity: [high]
- [ ] PL.4 `/playlist add <video> [to <playlist>]` and `/playlist remove <video>` (sidebar pickers for video + playlist). complexity: [high]
- [ ] PL.5 Reorder UI: drag/keyboard reorder in a playlist sidebar → `playlistItems.update` position; persist mirror. complexity: [high]
- [ ] PL.6 `/playlist privacy <playlist> <public|private|unlisted>`. complexity: [low]
- [ ] PL.7 Import existing playlists (`playlists.list` + `playlistItems.list`) into the mirror. complexity: [high]
- [ ] PL.8 Specs (stubbed API for every op; ordering; privacy; dedupe). complexity: [high]
- [ ] PL.9 Commit(s): `Playlist management (create/add/remove/order/privacy)`. complexity: [manual]

---

## E. Still to cover (not yet designed)

- Further UI enhancements beyond those listed.
- `Pito::Stats` design (daily snapshot tables/jobs for channel + video totals) — pairs with P60.
- `Pito::Analytics` (wire TAB channel + Shift+TAB period into real queries).
- Real chat/slash domain handlers (list videos, channel overview…).
- Games detail screen (host for ScoreBar + TTB + probe snippet + `/add game` detail pane).
- A **videos list screen** (host for `/edit video` + lifecycle actions + a friendlier video picker).
- `Calendar` / `CalendarEntry` models — add when needed.
- Remote footage ingest (script + HTTP endpoint) if/when on Hetzner.

## F. Query-language ideas (chat/slash, later)

- `list` / `show` / `view|show @handle`.
- `list top channels` [`by subs|subscribers` | `by views and watched hours|time`].
- `list channels ordered by subs|subscribers (count)`.
- `list first|last 3 channels ordered|sorted by subs|subscribers (count)`.
- `force` / `refresh stats` with a `--fresh` argument.
- "Game in main screen"; "sidebar only for preview".

## G. Component extraction backlog

> From the ERB-spaghetti audit. Extract following the InlineSeparator/Shortcut/Hint precedent.

- [ ] Phase 1 (high ROI): `Pito::Separator::DividerLineComponent` (5+ `border-t border-line-default` sites); `Pito::Table::KeyValueRowComponent` (4+ key/value rows in keybinding/system/error/expandable); `Pito::Section::SectionHeaderComponent` (`font-bold mb-1` + yellow/orange, 4+ sites).
- [ ] Phase 2: `Pito::Badge::CodeBadgeComponent`; `Pito::List::PaletteItemComponent` (slash + autocomplete rows); shortcut+value display unification.
- [ ] Phase 3: `Pito::Table::CredentialRowComponent`; `Pito::Status::StatusIndicatorComponent` (●/○ dot); `Pito::List::NotificationRowComponent`.

## H. At merge

- Delete `docs/plan-beta-reboot-*.md` once Beta is merged; fold durable content into `architecture.md` / `design.md` / `installation.md` / `tools.md`.
