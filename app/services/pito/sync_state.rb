module Pito
  # Pito::SyncState — single source of truth for which targets are
  # user-paused.
  #
  # 2026-05-25 (pause-from-sync) — explicit pause/resume layer that sits
  # on top of (but is distinct from) the sync-enable/disable layer
  # (`AppSetting.sync_enabled?` / `AppSetting.set_sync`).
  #
  # ## Vocabulary
  #
  # * **disabled**  — the user has turned the target's sync flag OFF via
  #   the `[x] sync` / `[ ] sync` toggle (AppSetting key `sync.<target>`
  #   = "no"). Controlled by `SyncController#toggle`.
  #
  # * **paused**    — the user has explicitly paused the target via the
  #   `:` palette "pause <target>" command. The sync flag remains "yes";
  #   background jobs and cable broadcasts are suppressed until resumed.
  #   Stored in `AppSetting.singleton_row.paused_targets` (JSON array).
  #
  # * **uncertain** — the target is enabled+unpaused but a child target
  #   was individually resumed while this parent was paused, leaving the
  #   parent in an indeterminate state. See cascade rules below.
  #
  # ## Public API
  #
  #   Pito::SyncState.paused?(target) → Boolean
  #   Pito::SyncState.pause!(target)  → broadcasts, cascades children
  #   Pito::SyncState.resume!(target) → broadcasts, may mark parent uncertain
  #   Pito::SyncState.state(target)   → :syncing | :paused | :uncertain
  #
  # ## Cascade rules (parent ↔ child)
  #
  # TOP-DOWN (pause! parent):
  #   Pausing a parent pauses every known child (any target whose name
  #   starts with `target + "."`). Each child gets `mark_paused!` +
  #   `broadcast_pause(paused: true)`.
  #
  # BOTTOM-UP (resume! child while parent is still paused):
  #   Resuming a child while its parent is still paused does NOT auto-
  #   resume the parent. Instead the parent transitions to `:uncertain`
  #   — the operator can see the mixed state (some children paused, some
  #   not) and can explicitly resume the parent to clear it.
  #   Broadcasting `uncertain` on the parent fires `kind: "uncertain"` on
  #   the parent's channel so connected clients repaint the parent glyph.
  #
  # FULL RESUME (resume! parent):
  #   Resuming a parent resumes every known child too (same cascade as
  #   pause! but in reverse). Each child gets `mark_resumed!` +
  #   `broadcast_pause(paused: false)`.
  #
  # ## Cable channels
  #
  # pause!/resume! derives the cable channel from the dot-namespaced
  # target by replacing "." with ":" and prepending "pito:" — matching
  # the `Pito::CableBroadcaster` channel grammar. e.g.:
  #   "home.stack"             → "pito:home:stack"
  #   "home.stack.meilisearch" → "pito:home:stack:meilisearch"
  #
  # @contract see docs/architecture.md § Cable channel grammar
  module SyncState
    extend self

    # Returns true when the given dot-namespaced target is currently
    # paused by the user. Does NOT check ancestors.
    def paused?(target)
      AppSetting.paused_targets_set.include?(target.to_s)
    end

    # Pauses the target. Cascades to every known child target.
    #
    # For each target in the cascade (self + children):
    #   1. Writes `AppSetting.mark_paused!`
    #   2. Broadcasts `kind: "pause"` with `paused: true`
    #
    # No parent rollup. Use `state(target)` to derive the current state
    # for display; the caller decides whether to mark parent uncertain
    # (only resume! does that automatically).
    def pause!(target)
      target = target.to_s
      targets_to_pause = cascade_down(target)
      targets_to_pause.each do |t|
        AppSetting.mark_paused!(t)
        Pito::CableBroadcaster.broadcast_pause(
          target: channel_for(t),
          paused: true
        )
      end
    end

    # Resumes the target. Cascades to every known child target.
    #
    # For each target in the cascade (self + children):
    #   1. Writes `AppSetting.mark_resumed!`
    #   2. Broadcasts `kind: "pause"` with `paused: false`
    #
    # Then, if the resumed target is a child (its parent is STILL paused),
    # broadcasts `kind: "uncertain"` on the parent to reflect the mixed
    # state. The parent's `paused_targets_set` membership is NOT changed
    # — the parent stays paused. The uncertain broadcast is informational.
    def resume!(target)
      target = target.to_s
      targets_to_resume = cascade_down(target)
      targets_to_resume.each do |t|
        AppSetting.mark_resumed!(t)
        Pito::CableBroadcaster.broadcast_pause(
          target: channel_for(t),
          paused: false
        )
      end

      # Check if a parent is still paused → broadcast uncertain on parent.
      parent = parent_of(target)
      if parent && paused?(parent)
        Pito::CableBroadcaster.broadcast_uncertain(
          target: channel_for(parent),
          reason: "child #{target} resumed while parent #{parent} is still paused"
        )
      end
    end

    # Returns the current pause/sync state for a target:
    #
    #   :paused    — target is in the paused set.
    #   :uncertain — target is not paused but at least one known child IS
    #                paused (mixed: some children paused, some not).
    #   :syncing   — target is enabled, not paused, no children paused.
    #
    # Does NOT reflect the sync-enable gate (`AppSetting.sync_enabled?`);
    # disabled targets are `:syncing` here (the indicator chooses :idle
    # separately via the enable gate). This method is a pause-layer read.
    def state(target)
      target = target.to_s
      return :paused if paused?(target)

      children = children_of(target)
      if children.any? { |c| paused?(c) }
        return :uncertain
      end

      :syncing
    end

    private

    # Returns [target] + all children in the cascade. For a leaf target
    # returns [target]. Children = any known target starting with "target.".
    def cascade_down(target)
      kids = children_of(target)
      [ target ] + kids
    end

    # Returns known child targets (dot-namespaced children of `target`).
    # Reads from `Pito::SyncTargets::PARENTS_TO_CHILDREN` — the canonical
    # sub-panel registry. Falls back to inline scan of all targets for any
    # target not in the explicit map.
    def children_of(target)
      if Pito::SyncTargets::PARENTS_TO_CHILDREN.key?(target)
        return Pito::SyncTargets::PARENTS_TO_CHILDREN[target].dup
      end
      prefix = "#{target}."
      (Pito::SyncTargets.panel_targets + Pito::SyncTargets.sub_panel_targets)
        .select { |t| t.start_with?(prefix) }
    end

    # Returns the parent target or nil. Scans PARENTS_TO_CHILDREN for the
    # first parent whose children list includes `target`.
    def parent_of(target)
      Pito::SyncTargets::PARENTS_TO_CHILDREN.each do |parent, children|
        return parent if children.include?(target)
      end
      nil
    end

    # Converts a dot-namespaced target to a `pito:` cable channel name.
    #   "home.stack"             → "pito:home:stack"
    #   "home.stack.meilisearch" → "pito:home:stack:meilisearch"
    def channel_for(target)
      "pito:#{target.to_s.tr(".", ":")}"
    end
  end
end
