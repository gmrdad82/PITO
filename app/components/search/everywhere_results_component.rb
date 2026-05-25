# Phase 37 — "everywhere" omnisearch results body.
#
# Standalone sibling of `Search::OmnisearchResultsComponent`. Wraps
# two section components (games / channels) in a context-aware order
# driven by `current_path`. Built fresh per the user's 2026-05-19
# strict-independence rule — no inheritance and no template sharing
# with `OmnisearchResultsComponent`.
#
# R1 (2026-05-25) — bundles removed.
#
# Section-ordering contract:
#   - `/channels*`  → channels, games
#   - `/games*`     → games, channels
#   - any other     → channels, games  (default — navbar
#                       personal-importance order)
#
# Per 2026-05-19 user feedback the modal renders as a single flat
# list — no per-section headings, no per-section hairlines, no
# per-section empty-state copy. The kind label on each row's right
# edge already conveys what category each result belongs to. The
# only empty-state surface is a single line shown when ALL sections
# returned zero hits.
#
# Args:
#   query:         sanitized search string. Blank renders the blank-
#                   query hint instead of section stacks.
#   current_path:  request.path string. Drives section ordering.
#   game_hits:     Enumerable of Game records (Meilisearch hits).
#   channel_hits:  Enumerable of channel-shaped Hashes (mock data
#                   today — `Channel::MockData` entries with `:id`,
#                   `:display_name`, `:avatar_url`, `:handle`, etc.).
module Search
  class EverywhereResultsComponent < ViewComponent::Base
    FRAME_ID = "everywhere_results".freeze

    def initialize(query:, current_path:, game_hits:, channel_hits:)
      @query = query.to_s
      @current_path = current_path.to_s
      @game_hits = game_hits
      @channel_hits = channel_hits
    end

    attr_reader :query, :current_path, :game_hits, :channel_hits

    def frame_id
      FRAME_ID
    end

    def query_blank?
      @query.strip.empty?
    end

    # Returns the three section configs in context order. Each entry
    # carries `:kind` (drives row component branch + i18n keys) and
    # `:hits` (the collection). Headings dropped per 2026-05-19 flat-
    # list refactor.
    def sections_in_order
      base = {
        games:    { kind: :game,    hits: game_hits },
        channels: { kind: :channel, hits: channel_hits }
      }

      if current_path.start_with?("/channels")
        [ base[:channels], base[:games] ]
      elsif current_path.start_with?("/games")
        [ base[:games], base[:channels] ]
      else
        [ base[:channels], base[:games] ]
      end
    end

    # True when every section has zero hits — used by the template to
    # render a single blanket "no results" line instead of two empty
    # section paragraphs stacked.
    def truly_empty?
      Array(game_hits).empty? && Array(channel_hits).empty?
    end
  end
end
