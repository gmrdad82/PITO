module Pito
  # Pito::LatestVideosPanelComponent — home-screen panel showing the
  # most recent uploads across all owner channels, sortable by
  # publish date / channel / view-count.
  #
  # ## Round status
  #
  # Wave 2B blank-shell round: renders a `Tui::FramedPanelComponent`
  # chrome with the i18n-resolved title and a `[ panel content TBD ]`
  # placeholder body. Real content (latest-uploads list +
  # cross-channel ordering) lands in a future content round per
  # `docs/architecture.md` § Home panels.
  #
  # ## Canonical wiring
  #
  # - Includes `Tui::PanelBase` for the `panel_root_data` Hash spread
  #   into the section content_tag (controller / cursor target / cable
  #   screen+name values / focusables / keybinds).
  # - Cable channel: `pito:home:latest_videos` (canonical grammar).
  # - Focusables / keybinds: empty in the blank round; populated when
  #   real content lands.
  #
  # ## TUI parity
  #
  # The Ratatui sibling component reads the same panel data attrs
  # emitted here to derive its focusables list + cable subscription.
  # Do NOT inline data attrs in the template — emit via
  # `panel_root_data` so the canonical shape stays in one place.
  class LatestVideosPanelComponent < ViewComponent::Base
    include Tui::PanelBase

    PANEL_NAME = :latest_videos

    def title
      I18n.t("tui.home.panels.#{PANEL_NAME}.title")
    end

    def panel_data
      panel_root_data(name: PANEL_NAME, focusables: [], keybinds: {})
    end
  end
end
