module Tui
  # Tui::SyncIndicatorComponent — 3-state visual sync indicator for TST.
  #
  # NO brackets, NO glyphs. Just the word "sync" with color states:
  #   - "synced"       muted color, no animation
  #   - "syncing"      accent color + shimmer
  #   - "disconnected" danger red, no animation
  #
  # The word's letters scramble (240 ms, 8 frames × 30 ms) on every state
  # transition. JS drives state changes:
  #   pito:cable-activity   → "syncing" (debounced back to "synced" after 300 ms)
  #   tui:sync-changed      → "disconnected" / "synced" on cable lifecycle events
  #
  # Kwargs:
  #   initial_state [String] One of "synced", "syncing", "disconnected".
  #                           Defaults to "synced".
  #
  # Single instance: TST master only. No click, no target mode, no
  # per-panel mounting.
  #
  # Related:
  #   app/javascript/controllers/tui_sync_indicator_controller.js
  #   app/assets/tailwind/application.css  (§ tui-sync-indicator)
  class SyncIndicatorComponent < ViewComponent::Base
    STATES = %w[synced syncing disconnected].freeze
    DEFAULT_STATE = "synced".freeze

    def initialize(initial_state: DEFAULT_STATE)
      @initial_state = STATES.include?(initial_state.to_s) ? initial_state.to_s : DEFAULT_STATE
    end

    attr_reader :initial_state
  end
end
