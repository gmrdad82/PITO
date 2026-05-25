module Pito
  # ADR 0018 — Action bus + cable architecture.
  #
  # Canonical entry point for every cable broadcast in pito. Enforces
  # the ADR 0017 envelope (`{ kind, payload, ts }`) and the
  # `pito:<screen>:<panel>[:<sub-panel>]` channel grammar so consumers
  # can never broadcast a raw shape or invent a non-pito channel name.
  #
  # Surfaces:
  #
  #   `.broadcast_status_bar(payload)` — global TST channel. Always
  #     `kind: "data"`; payload carries `sync_state`, `busy`, Sidekiq
  #     counters, clock.
  #
  #   `.broadcast_panel(channel, kind:, payload:)` — any panel- or
  #     sub-panel-scoped channel matching the `pito:` grammar. Caller
  #     specifies the kind (`indeterminate`, `progress`, `complete`,
  #     `error`, `reindex_event`, …). Z2e: sync-suppression gate removed.
  #
  #   `.broadcast_sync_state(target:, enabled:)` — sync-state toggle
  #     broadcast on `pito:sync_state`. Clients re-paint sync indicator
  #     glyphs from `{ target, enabled }`.
  #
  # Canonical kinds (all panel-scoped streams):
  #   indeterminate, progress, complete, error, reindex_event
  module CableBroadcaster
    extend self

    STATUS_BAR_CHANNEL = "pito:status_bar".freeze
    SYNC_STATE_CHANNEL = "pito:sync_state".freeze

    # `kind:` is optional and defaults to `"data"` so the existing
    # Sidekiq middleware + StackStatsBroadcastJob keep their original
    # call shape (`broadcast_status_bar(payload)`). FB-test-infra
    # (2026-05-22) added the `kind:` kwarg so the dev/test rake
    # surface (`bundle exec rake pito:test:broadcast_*`) can broadcast
    # synthetic envelopes with arbitrary kinds (`sidekiq`,
    # `notifications`, …) without inventing a sibling broadcaster.
    def broadcast_status_bar(payload, kind: "data")
      ActionCable.server.broadcast(
        STATUS_BAR_CHANNEL,
        { kind: kind.to_s, payload: payload, ts: Time.current.iso8601 }
      )
    end

    # Z2e (2026-05-25) — sync-enabled gate removed alongside Pito::SyncTargets.
    # The 3-state indicator (synced/syncing/disconnected) is pure JS; per-panel
    # suppression is no longer a server-side concern. Broadcasts fire unconditionally.
    def broadcast_panel(channel, kind:, payload:)
      raise ArgumentError, "channel must start with pito:" unless channel.to_s.start_with?("pito:")
      ActionCable.server.broadcast(
        channel,
        { kind: kind, payload: payload, ts: Time.current.iso8601 }
      )
    end

    # Emits a `pause` envelope on the target stream.
    #
    # Use when a background job or real-time process is temporarily
    # paused (e.g. a sync loop waiting for rate-limit headroom).
    # The caller decides the boolean semantics of `paused:`.
    #
    # Payload: `{ target:, paused:, ts: }`.
    # Honors the sync-enabled gate (dropped when target or ancestor is
    # disabled).
    def broadcast_pause(target:, paused:)
      broadcast_panel(
        target.to_s,
        kind: "pause",
        payload: { target: target.to_s, paused: !!paused, ts: Time.current.iso8601 }
      )
    end

    # Emits an `uncertain` envelope on the target stream.
    #
    # Use when the state of a remote resource cannot be confidently
    # determined (e.g. an API timeout, an ambiguous diff result). The
    # `reason:` string is a short, user-facing hint surfaced by the JS
    # panel controller.
    #
    # Payload: `{ target:, uncertain: true, reason:, ts: }`.
    # Honors the sync-enabled gate (dropped when target or ancestor is
    # disabled).
    def broadcast_uncertain(target:, reason:)
      broadcast_panel(
        target.to_s,
        kind: "uncertain",
        payload: { target: target.to_s, uncertain: true, reason: reason.to_s, ts: Time.current.iso8601 }
      )
    end

    # Sync-state envelope (sent once per cascaded target by
    # `SyncController#toggle`). All clients listen on
    # `pito:sync_state`; the JS sync-indicator controllers re-paint
    # their glyphs from the `{ target, enabled }` payload.
    def broadcast_sync_state(target:, enabled:)
      ActionCable.server.broadcast(
        SYNC_STATE_CHANNEL,
        {
          kind: "sync_state",
          payload: { target: target.to_s, enabled: !!enabled },
          ts: Time.current.iso8601
        }
      )
    end
  end
end
