# Phase 37 — "everywhere" omnisearch row.
#
# Standalone sibling of `Search::OmnisearchResultRowComponent`. Handles
# two row kinds in a single component because every row in the
# "everywhere" modal is a navigation link.
#
# R1 (2026-05-25) — `:bundle` kind removed with bundles.
#
# Kinds:
#   :game    — Game record. Title + release-year suffix + muted
#               "game" label. Link to `game_path(record)`.
#   :channel — channel-shaped Hash (mock data — `:id`, `:display_name`,
#               `:handle`, `:avatar_url`, optional `:subscriber_count`).
#               Avatar (circular per design.md §"Channel avatars") +
#               display_name + @handle + muted "channel" label. Link
#               to `/channels` (the only channel surface today).
#
# Args:
#   kind:   one of :game | :channel.
#   record: the underlying object — Game model or Hash for :channel.
module Search
  class EverywhereRowComponent < ViewComponent::Base
    KINDS = %i[game channel].freeze

    def initialize(kind:, record:)
      raise ArgumentError, "unknown row kind: #{kind.inspect}" unless KINDS.include?(kind)

      @kind = kind
      @record = record
    end

    attr_reader :kind, :record

    # Avatar tile dimension for the :channel row. Matches the chip-row
    # tile sizing in `Channel::AvatarChipComponent` (1.4em + 4px
    # overflow) so the visual rhythm stays consistent across surfaces.
    def channel_avatar_dimension_css
      "calc(1.4em + 4px)"
    end
  end
end
