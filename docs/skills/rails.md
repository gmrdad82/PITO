# Rails skill — pito extensions

## JSON-only

Every controller action returns JSON. The only ERB template is the xterm.js
shell at `app/views/layouts/application.html.erb`. No ViewComponents, no
Turbo, no Stimulus, no Tailwind, no CSS pipeline.

## Action Cable

Status bar uses Action Cable. Pito::CableBroadcaster pushes to
`pito:status_bar`. Both web (via @rails/actioncable) and CLI (via
WebSocket) subscribe.

## Test conventions

- Request specs at `spec/requests/`
- Service specs at `spec/services/pito/`
- Model specs at `spec/models/`
- No component specs, no system specs, no view specs.

## Secrets

API keys, webhook URLs, OAuth client secrets in Rails.application.credentials.
Access via `bin/rails credentials:edit`.

## Rake tasks

- `pito:test_broadcast` — push dummy Sidekiq jobs for status bar testing
- `pito:theme:export` — write CSS + Rust theme tokens
- `pito:auth:enroll` — TOTP enrollment
