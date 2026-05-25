# 2026-05-18 — Per-row markup for an omnisearch result list.
#
# R1 (2026-05-25) — Bundle-related kinds removed with bundles.
#
# One component, two kinds — each kind maps to a `<li>` shape used
# across the omnisearch modes (game_index / games_search). Modes pick
# which kinds they render; the row component itself only knows how to
# render a single row.
#
# Kinds:
#   :local_game_link  — clickable title → /games/:slug, muted "game"
#                        label. Used by :games_search.
#   :igdb_add         — title + [add] POST /games. Used by
#                        :game_index and :games_search.
#
# 2026-05-19 — Dropped the `:igdb_open` kind. The dispatcher
# (`Game::SearchService`) now dedupes IGDB rows against local Games
# by `igdb_id` before reaching the view, so an IGDB row that exists
# locally is never rendered — there is no [open] branch to maintain.
# A local hit always wins via the `:local_game_link` row above.
#
# Args (vary by kind):
#   kind:           one of the two symbols above.
#   record:         the Game (for :local_game_link). nil for raw IGDB rows.
#   igdb_row:       the IGDB hash (id, name, first_release_date)
#                    for :igdb_add. nil otherwise.
module Search
  class OmnisearchResultRowComponent < ViewComponent::Base
    KINDS = %i[
      local_game_link
      igdb_add
    ].freeze

    def initialize(kind:, record: nil, igdb_row: nil)
      raise ArgumentError, "unknown row kind: #{kind.inspect}" unless KINDS.include?(kind)
      @kind = kind
      @record = record
      @igdb_row = igdb_row
    end

    attr_reader :kind, :record, :igdb_row

    # Release year extracted from the IGDB hash; nil-safe. Returns nil
    # when the IGDB row carries no `first_release_date`.
    def igdb_release_year
      ts = igdb_row && igdb_row["first_release_date"]
      return nil if ts.blank?
      Time.at(ts).utc.year
    end
  end
end
