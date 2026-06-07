# frozen_string_literal: true

module Pito
  module Recommendation
    # Single source of truth for recommendation signal weights, shared by every
    # direction (game→game, game→channel, channel→game). Tunable in one place.
    #
    # Seven signals blended into 0–100 (weights sum to 1.0):
    #   PP — player_perspective overlap. The strongest discriminator: a
    #        third-person action game and a side-view platformer are *not* the
    #        same kind of game even when their genre tags collide ("Adventure").
    #   E  — embedding / semantic similarity.
    #   G  — genre overlap.
    #   S  — score proximity.
    #   T  — theme overlap (Action / Sci-fi / Horror / Survival …).
    #   D  — developer overlap (counts for something).
    #   P  — publisher overlap (counts less).
    #
    # Weights tuned empirically against real IGDB data so that, vs Pragmata:
    # Dead Space ≈ 81, Mad Max ≈ 65, Ghosts 'n Goblins ≈ 28, Super Meat Boy ≈ 6.
    #
    # An explicit video→game link is definitive and bypasses the blend entirely
    # (LINK_SCORE). Anything below FLOOR is dropped (kept low so weak-but-real
    # matches like Super Meat Boy still surface).
    module Weights
      PP = 0.45 # player perspective overlap (primary discriminator)
      E  = 0.20 # embedding / semantic similarity
      G  = 0.20 # genre overlap
      S  = 0.06 # score proximity
      T  = 0.05 # theme overlap
      D  = 0.03 # developer overlap (counts for something)
      P  = 0.01 # publisher overlap (counts less)

      BLEND = { e: E, g: G, t: T, pp: PP, s: S, d: D, p: P }.freeze

      LINK_SCORE = 100 # explicit link → definitive match
      FLOOR      = 5   # drop blended scores below this (near-noise only)

      # Blend a breakdown hash ({ e:, g:, t:, pp:, s:, d:, p: } each 0–100) into a
      # single 0–100 score using the weights above. Missing keys count as 0.
      def self.blend(breakdown)
        BLEND.sum { |key, weight| weight * breakdown[key].to_f }.round
      end
    end
  end
end
