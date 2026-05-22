module Tui
  # Beta 4 — extracted from `Tui::TopStatusBarComponent` (2026-05-22) per
  # "ViewComponents are kings". The breadcrumb segment of the top
  # status bar.
  #
  # Renders the SSR fallback as `<screen>` (no panel / sub-panel), and
  # the `tui-breadcrumb` Stimulus controller swaps in
  # `<screen> <panel>` or `<screen> <panel>:(<sub-panel>)` after listening
  # for the `tui:panel-focus-changed` custom event broadcast by
  # `tui_cursor_controller.js`.
  #
  # Visual contract (driven by CSS that already lives in
  # `app/assets/tailwind/application.css`):
  #   - `<screen>`     → `.sb-section`     — bold, section-accent color
  #   - `<panel>`      → `.sb-section__panel`     — bold, section-accent
  #   - `:(` and `)`   → `.sb-section__sub-panel-paren` — muted variant
  #   - `<sub-panel>`  → `.sb-section__sub-panel` — accent-bright
  #
  # Constructor inputs:
  #   - screen:    required string (one of "home", "channels", "games",
  #                "settings", "videos", "projects").
  #   - panel:     optional string. When present, replaces `<screen>`
  #                in the SSR paint (Stimulus still patches via the
  #                cable→event flow).
  #   - sub_panel: optional string. Only renders when `panel` also
  #                renders.
  #
  # The component honors the existing `data-tui-status-bar-target="section"`
  # contract so `tui_status_bar_controller.js`'s `seedSectionFromFocusedPanel`
  # + `handlePanelFocus` keep working unchanged.
  class BreadcrumbComponent < ViewComponent::Base
    def initialize(screen:, panel: nil, sub_panel: nil)
      @screen = screen.to_s
      @panel = panel.presence
      @sub_panel = sub_panel.presence
    end

    attr_reader :screen, :panel, :sub_panel

    def label
      @panel || @screen
    end

    def sub_panel_visible?
      @panel.present? && @sub_panel.present?
    end

    def paren_open
      I18n.t("tui.tst.breadcrumb.paren_open")
    end

    def paren_close
      I18n.t("tui.tst.breadcrumb.paren_close")
    end
  end
end
