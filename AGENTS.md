# pito — CodeWhale collaboration rules

## Project at a glance

pito is a self-hosted YouTube channel management tool. Two terminal-native
clients share one JSON API backend:

- **Web client** — xterm.js terminal served by Rails at `app.pitomd.com`
- **Rust TUI** — Ratatui terminal at `extras/cli/`
- **Astro landing** — `extras/website/`, deployed to Cloudflare Pages
- **Rails API** — JSON-only backend, no HTML views, no CSS pipeline

Future deployment: Hetzner via Kamal.

Purpose: manage titles, descriptions, thumbnails, playlists, visibility
for videos across the owner's YouTube channels.

**Both clients share:** Tokyo Night theme, 5-zone terminal layout (header,
main conversation log, right sidebar, input line, status bar), command
parity (`/help /status /channels /videos /games /reindex /config /auth`),
shared keybindings from `config/keybindings.yml`.

Status bar updates via Action Cable (Rails cable → WebSocket → both
clients). No polling. Cable broadcasts `pito:status_bar` stream.

For system topology → `docs/architecture.md`.
For design rules, keybindings, terminology → `docs/design.md`.

## How we work

**Skills from `~/Dev/agents/skills/`.** The master session loads skills
from the central agents repo. Each skill has a SKILL.md body + optional
project-specific extension at `docs/skills/<name>.md`.

**Master dispatches sub-agents via `agent_open`.** Sub-agents stay within
declared file scope. Parallelize independent work. Kill sub-agents that
exceed 5 minutes; investigate and slice smaller if >10 minutes.

**One concern per dispatch.** "AND" in a dispatch prompt means it's two
dispatches. Bundle work by file scope, not by topic.

**Model selection:** DeepSeek V4 Pro for architecture, debugging, security.
V4 Flash for mechanical work (renames, simple deletions, file audits).

**Parallel by default.** Independent tasks that touch disjoint files run
in the same turn via multiple `agent_open` calls.

**Commits:** commit after each milestone. `[skipci]` prefix. Commit to
`main` directly — no branches, no PRs. Use `--no-gpg-sign` if signing
prompt times out.

## Canonical namespace

Everything lives under `Pito::*` unless a domain claims it.

### Cross-cutting (`Pito::*`)
- `Pito::CableBroadcaster` — pushes status bar payloads to Action Cable
- `Pito::Theme` — Tokyo Night palette atoms + CSS/Rust export
- `Pito::Auth::*` — TOTP auth flows
- `Pito::AssetsRoot` — filesystem path helper for covers/thumbnails
- `Pito::Schedule::*`, `Pito::Calendar::*`, `Pito::Analytics::*`

### Domain layer (singular)
- `Channel::*`, `Video::*`, `Game::*`, `Bundle::*`, `Footage::*`

### Jobs
- Sidekiq jobs under `app/jobs/` (flat, no namespace)
- `Pito::Test::SimpleSidekiqJob` — dummy job for status bar testing
- `StatusBarBroadcastMiddleware` — Sidekiq middleware at `app/sidekiq/`

## Hard rules

**JSON-only Rails.** Every controller action returns JSON. No `format.html`
blocks. One ERB layout (`app/views/layouts/application.html.erb`) serves
the xterm.js web shell. No other views exist.

**Action Cable for status bar.** Sidekiq middleware broadcasts queue stats
to `pito:status_bar` stream. Both clients subscribe. No polling.

**Secrets in `Rails.application.credentials`.** Never in `.env*` files.

**Yes / no for external booleans.** Every URL param, JSON, MCP I/O, and
Rust wire boolean uses `"yes"` / `"no"`. Convert at boundaries.

**Keyboard-first.** Every action operable via keyboard. Mouse optional.

**Terminology:**
| Use | Not |
|---|---|
| screen | page |
| panel | pane |
| section | — |
| dialog | modal |
| action | button |

**Brand capitalization:** Slack, Discord, YouTube, Voyage AI, Meilisearch,
PostgreSQL, Redis, Chrome, Firefox, Safari, Linux, macOS, Windows.

**Source of truth:**
1. User decision in chat → capture to docs
2. `docs/architecture.md` / `docs/design.md` / `docs/tui.md`
3. Code

## Task flow

1. **User asks** — free-form request, image, or bug report.
2. **Plan** — read needed files, propose plan, get approval for non-trivial work.
3. **Dispatch** — small focused sub-agents (≤5 min, one concern, parallel).
4. **Audit** — verify sub-agent deliveries (success, specs, docs, namespace).
5. **Surface** — concise validation to user.
6. **Fix** — re-dispatch for failures.
7. **Commit** — `[skipci] title (≤72 chars)`. Bullet summary in body.

## Skills

Per-skill project extensions live under `docs/skills/`. Available skills
from `~/Dev/agents/skills/` with their pito scopes:

| Skill | pito scope |
|---|---|
| `rails` | `app/` — controllers, models, services, jobs, cable, RSpec |
| `rust` | `extras/cli/` — TUI, API client, keybindings, theme |
| `ai` | DeepSeek integration (Voyage embeddings, API config) |
| `postgres` | `db/migrate/`, schema, queries |
| `redis` | Sidekiq config, caching, cable adapter |
| `meilisearch` | Search index config, document indexing |
| `voyage` | Vector embeddings indexer |
| `docker` | `Dockerfile`, `docker-compose.yml`, Kamal deploy |
| `reviewer` | Code review pipeline (static analysis, tests, security, deps) |
| `security` | Threat-model review against current diff |
| `docs` | Keep `docs/` in sync after features land |
| `auditor` | Ground-truth gap report (repo vs plan) |
| `architect` | Feature specs before implementation |
| `git-precommit-guard` | Pre-commit safety checks |
| `astro` | `extras/website/` landing page |
| `omarchy` | System config (Hyprland, Waybar, themes) — read-only on pito |

## Communication

- Slack pings via webhook to `#pito-app` on milestones. Concise, signal-only.
- Chat is the detail surface.
- Emojis in chat only (not code, commits, docs, specs, locales).

## Pointers

- `docs/architecture.md` — system topology, models, cable, jobs, namespace
- `docs/design.md` — theme tokens, keybindings, terminology, layout contract
- `docs/tui.md` — Rust client contract, screen parity, API client patterns
- `docs/website.md` — Astro landing build + deploy
