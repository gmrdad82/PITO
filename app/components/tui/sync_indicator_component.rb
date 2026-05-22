module Tui
  # Beta 4 — extracted from `Tui::TopStatusBarComponent` (2026-05-21)
  # per "ViewComponents are kings" — sub-elements of the top status
  # bar each get their own VC + spec.
  #
  # Sync indicator: ●/✗ glyph + word ("synced" / "syncing" /
  # "disconnected") + optional target label rendered immediately
  # after the word for `:syncing_with_target`.
  #
  # Visual rules + class hooks mirror the locked demo at
  # `tmp/demo-status-bar-final.html` and Lane C's
  # `tui_status_bar_controller.js` which patches the same DOM cells.
  #
  # Constructor inputs:
  #   - state:  one of `:idle`, `:syncing`, `:syncing_with_target`,
  #             `:disconnected`. Drives the dot glyph + dot color +
  #             word + word color. Defaults to `:idle`.
  #   - target: optional string. Rendered after the word for
  #             `:syncing_with_target` (e.g. "syncing channels"
  #             → target="channels"). Ignored for other states.
  #
  # The root element + each child carry the
  # `data-tui-status-bar-target="..."` attributes that the cable
  # Stimulus controller subscribes to — this VC is a drop-in render
  # inside `Tui::TopStatusBarComponent` and does not break the live
  # update contract.
  #
  # 2026-05-22 — Now also carries the `tui-sync-indicator` Stimulus
  # controller which listens for `tui:sync-changed` custom DOM events
  # (dispatched by the parent `tui-top-status-bar` controller on every
  # cable payload). The child controller patches the dot glyph + class
  # + word text/class in place. Word text flows through I18n keys
  # `tui.tst.sync.synced` / `.syncing` / `.disconnected` so the SSR +
  # JS layers share the same string source.
  class SyncIndicatorComponent < ViewComponent::Base
    STATES = %i[idle syncing syncing_with_target disconnected].freeze

    def initialize(state: :idle, target: nil)
      @state = STATES.include?(state.to_sym) ? state.to_sym : :idle
      @target = target.presence
    end

    attr_reader :state, :target

    def dot_glyph
      @state == :disconnected ? "✗" : "●"
    end

    def dot_class
      case @state
      when :idle              then "sb-sync-dot sb-sync-dot--green"
      when :syncing, :syncing_with_target then "sb-sync-dot sb-sync-dot--amber"
      when :disconnected      then "sb-sync-dot sb-sync-dot--red"
      end
    end

    def word
      case @state
      when :idle              then I18n.t("tui.tst.sync.synced")
      when :syncing, :syncing_with_target then I18n.t("tui.tst.sync.syncing")
      when :disconnected      then I18n.t("tui.tst.sync.disconnected")
      end
    end

    # i18n strings exposed to the Stimulus controller as data-* attrs
    # so the JS layer doesn't reach back into the server for label text
    # on every cable push.
    def word_synced
      I18n.t("tui.tst.sync.synced")
    end

    def word_syncing
      I18n.t("tui.tst.sync.syncing")
    end

    def word_disconnected
      I18n.t("tui.tst.sync.disconnected")
    end

    def word_class
      case @state
      when :idle              then "sb-sync-word sb-sync-word--idle"
      when :syncing, :syncing_with_target then "sb-sync-word sb-sync-word--syncing"
      when :disconnected      then "sb-sync-word sb-sync-word--disconnected"
      end
    end

    def target_visible?
      @state == :syncing_with_target && @target.present?
    end
  end
end
