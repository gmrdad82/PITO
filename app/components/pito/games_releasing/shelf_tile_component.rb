module Pito
  module GamesReleasing
    # Pito::GamesReleasing::ShelfTileComponent — one tile in the
    # `Pito::GamesReleasingPanelComponent`'s horizontal "upcoming games"
    # shelf.
    #
    # ## Layout (top-to-bottom)
    #
    #   - Cover art — `Game::CoverComponent` `:shelf_fill` variant.
    #     Fills the available tile height while CSS `aspect-ratio: 3 / 4`
    #     keeps the canonical cover proportion. The cover wrapper sits
    #     inside a flex `:flex-grow: 1; min-height: 0;` box so the
    #     panel-driven tile height drives the cover height.
    #   - Title — `.upcoming-tile__title`, single-line + `text-overflow:
    #     ellipsis` truncation. `title=` attr on the tile root carries
    #     the full title for hover-tooltip discoverability.
    #   - Platform chips — `Platforms::ChipComponent` for each chip slug
    #     the game resolves via `PlatformChipsHelper.game_detail_chip_slugs`.
    #     Always passes `size: :sm` (matches the existing tile-footer
    #     chip size). Suppressed when the slug list is empty (no
    #     platforms inferred — e.g. metadata-poor pre-release rows).
    #   - Relative time-to-release — `Pito::Formatter::CompactTimeAgo`
    #     via the existing `compact_time_ago` helper. Phrasing matches
    #     the rest of pito's compact-time surface ("in 5d" / "in 2w").
    #
    # ## Focusables + keyboard nav
    #
    # Each tile carries `data-tui-focusable="upcoming_<id>"` so the
    # `tui-cursor` controller's j/k focus-list traversal advances
    # left-to-right across the shelf row (focusables are queried in
    # DOM order; horizontal flex preserves left-to-right document
    # order). The Stimulus controller does not need a separate
    # "horizontal" mode — j/k already steps through focusables in
    # the order they appear in the DOM regardless of layout direction.
    #
    # ## TUI parity
    #
    # The Ratatui sibling reads the same fields (cover URL, title,
    # platform chip slugs, days-until). Horizontal scroll in Ratatui
    # is a `Table` widget with `column_spacing` + a horizontal
    # scrollbar widget (bottom-row). The bottom-edge `◀ ▶ ▬` glyphs
    # rendered by `tui_scroll_indicator_controller` (horizontal axis)
    # are the web side of the same affordance.
    class ShelfTileComponent < ViewComponent::Base
      def initialize(game:)
        @game = game
      end

      attr_reader :game

      # Stable focusable key. `upcoming_<id>` so multiple shelves on the
      # same page can coexist if a future round adds (e.g.) "upcoming
      # bundles" — the prefix scopes the slot to this shelf.
      def focusable_key
        "upcoming_#{game.id}"
      end

      # Path the tile links to. Wraps `helpers.game_path(game)` so a
      # future routing change propagates cleanly through one call site.
      def game_path
        helpers.game_path(game)
      end

      # Ordered platform chip slugs (`ps` / `switch` / `steam`) that
      # apply to this game. Walks `KNOWN_CHIPS` in declaration order
      # via the existing helper so the chip strip order matches the
      # rest of pito's chip surfaces.
      def chip_slugs
        helpers.game_detail_chip_slugs(game)
      end

      # Compact "in Nd" / "in Nw" string via
      # `Pito::Formatter::InTimeUntil` (the future-tense sibling of
      # `Pito::Formatter::CompactTimeAgo`). Surfaces nil when
      # `release_date` is missing so the template can suppress the
      # row instead of rendering an "unknown" placeholder for
      # metadata-poor pre-release rows.
      def time_until_release
        return nil if game.release_date.blank?
        helpers.in_time_until(game.release_date)
      end
    end
  end
end
