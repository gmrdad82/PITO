# 2026-05-18 — Shared omnisearch modal shell component.
#
# Replaces `app/views/shared/_omnisearch_modal.html.erb` per the
# CLAUDE.md "HTML structure = ViewComponent" rule. The two current
# consumers (the `/games` `[+]` IGDB-add modal and the `/`-keyed
# `/games` omnisearch modal) all instantiate this component directly
# with constructor args; no more template branching by a `:mode` local.
#
# R1 (2026-05-25) — `:bundle_add` mode removed with bundles.
#
# Mode resolution:
#   - `:game_index`   — IGDB-only add-from-IGDB flow.
#   - `:games_search` — local games + IGDB.
#
# Args:
#   mode:              one of :game_index, :games_search.
#   dialog_id:         DOM id for the `<dialog>` (unique on the page).
#   url:               omnisearch endpoint the Stimulus controller hits.
#   placeholder:       input placeholder string (caller resolves I18n).
#   results_frame_id:  DOM id of the inner `<turbo-frame>`.
module Search
  class OmnisearchModalComponent < ViewComponent::Base
    MODES = %i[game_index games_search].freeze

    def initialize(mode:, dialog_id:, url:, placeholder:, results_frame_id:)
      raise ArgumentError, "unknown mode: #{mode.inspect}" unless MODES.include?(mode)

      @mode = mode
      @dialog_id = dialog_id
      @url = url
      @placeholder = placeholder
      @results_frame_id = results_frame_id
    end

    attr_reader :mode, :dialog_id, :url, :placeholder, :results_frame_id

    def render_recommendations?
      false
    end
  end
end
