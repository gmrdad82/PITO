# Rust skill — pito extensions

## Workspace

The Rust TUI lives at `extras/cli/`. The binary is `pito`.

## Architecture

Single-screen 5-zone layout (no screen switching):
- Header (row 1): channel handles + "pito" brand
- Main area (rows 2..N-2): conversation log
- Right sidebar (30 cols): channels, videos, games sections
- Input line (row N-1): "> " prompt
- Status bar: HTML element in web, terminal row N in TUI

## Key modules

- `src/app.rs` — App struct (state, commands, polling)
- `src/commands/tui.rs` — event loop, key handling
- `src/ui/mod.rs` — render function (5-zone layout)
- `src/api/client.rs` — PitoClient trait
- `src/api/http_client.rs` — reqwest-based HTTP client
- `src/api/models.rs` — Channel, Video, DashboardData, StatusData
- `src/theme.rs` — Tokyo Night palette (dark + light)
- `src/auth.rs` — TOTP auth flow

## API surface

- GET /dashboard.json → DashboardData
- GET /channels.json → Vec<Channel>
- GET /videos.json → Vec<Video>
- POST /login (code=X) → auth
- POST /commands/execute ({"command":"..."}) → { output, error }

## Cable

Coming: WebSocket connection to /cable for status bar updates.
