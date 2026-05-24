module Pito
  # Pito::ChannelsOverviewPanelComponent — home-screen panel showing
  # cross-channel counts + subs / views / watched-hours trends across
  # configurable time windows (7d / 28d / 3m / this year / lifetime).
  #
  # ## Round status
  #
  # Wave 2B blank-shell round: renders a `Tui::FramedPanelComponent`
  # chrome with the i18n-resolved title and a `[ panel content TBD ]`
  # placeholder body. Real content (channel-count rollup + trend
  # sparklines) lands in a future content round per
  # `docs/architecture.md` § Home panels.
  #
  # ## Canonical wiring
  #
  # - Includes `Tui::PanelBase` for the `panel_root_data` Hash spread
  #   into the section content_tag (controller / cursor target / cable
  #   screen+name values / focusables / keybinds).
  # - Cable channel: `pito:home:channels_overview` (canonical grammar).
  # - Focusables / keybinds: empty in the blank round; populated when
  #   real content lands.
  #
  # ## TUI parity
  #
  # The Ratatui sibling component reads the same panel data attrs
  # emitted here to derive its focusables list + cable subscription.
  # Do NOT inline data attrs in the template — emit via
  # `panel_root_data` so the canonical shape stays in one place.
  class ChannelsOverviewPanelComponent < ViewComponent::Base
    include Tui::PanelBase

    PANEL_NAME = :channels_overview

    def title
      I18n.t("tui.home.panels.#{PANEL_NAME}.title")
    end

    # 2026-05-24 — panel-level `[ ] sync` action contributed as the
    # leading focusable. `target: "home.channels"` matches the panel's
    # canonical sync localStorage suffix.
    def focusables
      %w[channels_sync]
    end

    def panel_data
      panel_root_data(name: PANEL_NAME, focusables: focusables, keybinds: {})
    end
  end
end
