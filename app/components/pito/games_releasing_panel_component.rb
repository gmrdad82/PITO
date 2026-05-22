module Pito
  # Pito::GamesReleasingPanelComponent — home-screen panel showing
  # upcoming game releases (sourced via IGDB) that match the owner's
  # tracked games / wishlist scope.
  #
  # ## Round status
  #
  # Wave 2B blank-shell round: renders a `Tui::FramedPanelComponent`
  # chrome with the i18n-resolved title and a `[ panel content TBD ]`
  # placeholder body. Real content (upcoming releases pulled from
  # IGDB) lands in a future content round per
  # `docs/architecture.md` § Home panels.
  #
  # ## Canonical wiring
  #
  # - Includes `Tui::PanelBase` for the `panel_root_data` Hash spread
  #   into the section content_tag (controller / cursor target / cable
  #   screen+name values / focusables / keybinds).
  # - Cable channel: `pito:home:games_releasing` (canonical grammar).
  # - Focusables / keybinds: empty in the blank round; populated when
  #   real content lands.
  #
  # ## TUI parity
  #
  # The Ratatui sibling component reads the same panel data attrs
  # emitted here to derive its focusables list + cable subscription.
  # Do NOT inline data attrs in the template — emit via
  # `panel_root_data` so the canonical shape stays in one place.
  class GamesReleasingPanelComponent < ViewComponent::Base
    include Tui::PanelBase

    PANEL_NAME = :games_releasing

    def title
      I18n.t("tui.home.panels.#{PANEL_NAME}.title")
    end

    def panel_data
      panel_root_data(name: PANEL_NAME, focusables: [], keybinds: {})
    end
  end
end
