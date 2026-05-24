module Tui
  # Tui::TstNoticeComponent — ephemeral centered notice slot for the top
  # status bar.
  #
  # Phase 1D (2026-05-24) — added as part of the sync system end-to-end
  # rebuild. Mounts in the TST between the breadcrumb (left) and the
  # sync indicator / clock (right), center-aligned. Renders nothing on
  # the SSR first paint; the matching JS controller
  # (`tui_notice_controller`) listens for `tui:notice` document events
  # and patches the slot with the message verbatim for a short window
  # (default 2500ms), then fades out.
  #
  # The event detail shape:
  #
  #     document.dispatchEvent(new CustomEvent("tui:notice", {
  #       detail: { message: "sync paused", severity: "info" }
  #     }))
  #
  # The component does NOT do client-side i18n — emitters pass the
  # ready-to-display string in the event `message`. Severity is one of
  # `info | success | warn | danger`; the controller swaps a CSS class
  # accordingly.
  #
  # ## TUI parity
  #
  # The Ratatui screen export maps this slot to a centered paragraph in
  # the Rust client's top bar. The toggle event messages flow through
  # the same i18n keys both clients consume (`tui.notices.*`).
  #
  # ## Kwargs
  #
  # @param duration_ms [Integer] window the notice stays visible before
  #   fading. Defaults to 2500ms. The Stimulus controller reads this via
  #   `data-tui-notice-duration-value`.
  #
  # ## Stimulus contract
  #
  # The host span carries:
  #   - `data-controller="tui-notice"`
  #   - `data-tui-notice-duration-value="<ms>"`
  #   - `data-tui-notice-target="slot"` on the inner span (text host)
  #
  # @contract see docs/design.md § Transitions
  class TstNoticeComponent < ViewComponent::Base
    DEFAULT_DURATION_MS = 2500

    def initialize(duration_ms: DEFAULT_DURATION_MS)
      @duration_ms = duration_ms.to_i
      @duration_ms = DEFAULT_DURATION_MS if @duration_ms <= 0
    end

    attr_reader :duration_ms
  end
end
