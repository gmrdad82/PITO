# SyncController — mutation endpoints for server-side sync state.
#
# 2026-05-25 (sync-rebuild) — replaces every `localStorage.setItem`
# / `localStorage.getItem` call in the JS layer. The toggle handler
# walks `Pito::SyncTargets.cascade_targets(target)`, writes the same
# new value to every cascaded AppSetting row, and broadcasts ONE
# envelope per cascaded target on `pito:sync_state` so every connected
# client repaints in lockstep.
#
# 2026-05-25 (pause-from-sync) — two new actions for explicit pause /
# resume without disabling sync entirely:
#
#   POST /pito/sync/pause  — pause target + cascade children
#   POST /pito/sync/resume — resume target + cascade children
#
# Both actions are no-confirmation, reversible. They delegate to
# `Pito::SyncState` which owns cascade rules + cable broadcasts.
#
# All actions are cookie-authed via `Sessions::AuthConcern` (inherited
# from `ApplicationController`). Return `head :no_content` — Turbo-
# friendly, the UI updates via the cable broadcast.
class SyncController < ApplicationController
  def toggle
    target = params[:target].to_s
    return head :not_found unless Pito::SyncTargets.valid?(target)

    next_enabled = !AppSetting.sync_enabled?(target)
    cascade = Pito::SyncTargets.cascade_targets(target)

    cascade.each do |t|
      AppSetting.set_sync(t, next_enabled)
      Pito::CableBroadcaster.broadcast_sync_state(target: t, enabled: next_enabled)
    end

    head :no_content
  end

  # POST /pito/sync/pause — explicitly pause a target.
  #
  # `target` param carries the dot-namespaced sync target (e.g.
  # `home.stack`). Allowlisted via `Pito::SyncTargets.valid?`. Delegates
  # cascade + broadcast to `Pito::SyncState.pause!`.
  def pause
    target = params[:target].to_s
    return head :not_found unless Pito::SyncTargets.valid?(target)

    Pito::SyncState.pause!(target)
    head :no_content
  end

  # POST /pito/sync/resume — explicitly resume a paused target.
  #
  # `target` param carries the dot-namespaced sync target. Allowlisted
  # via `Pito::SyncTargets.valid?`. Delegates cascade + broadcast (and
  # possible uncertain on parent) to `Pito::SyncState.resume!`.
  def resume
    target = params[:target].to_s
    return head :not_found unless Pito::SyncTargets.valid?(target)

    Pito::SyncState.resume!(target)
    head :no_content
  end
end
