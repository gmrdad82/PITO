# frozen_string_literal: true

# KEPT BUT UNUSED — no host screen yet.
#
# Continuous rating bar with red→green gradient + absolute-positioned tick
# overlay + absolute-positioned score bubble.
#
# The score is read from `game.score` (the vote-weighted average
# computed by `Pito::Game::ScoreCalculator`).
#
# kwargs:
#   game:  (Game, optional) — source record for score synthesis.
#   score: (Integer, optional) — explicit override score; bypasses synthesis.
class Pito::ScoreBarComponent < ViewComponent::Base
  # Cell count of the continuous `=` run between the brackets. 20 cells over
  # the 0–100 score axis means each `=` spans a 5% slice (see the needle
  # cell-mid snap in `overlay_left_percent`).
  BAR_CELLS = 20

  TIERS = [
    [ 90, "excellent" ],
    [ 80, "good"      ],
    [ 70, "fair"      ],
    [ 60, "meh"       ],
    [ 50, "poor"      ],
    [ 25, "bad"       ]
  ].freeze

  def initialize(game: nil, score: nil)
    @game     = game
    @override = score
  end

  def score
    return @override if @override

    self.class.synthesized_score(@game)
  end

  def self.synthesized_score(game)
    return nil unless game

    Pito::Game::ScoreCalculator.call(game)
  end

  def synthesized_score
    self.class.synthesized_score(@game)
  end

  def self.tier_for(s)
    return "missing" if s.nil?

    TIERS.each do |min, name|
      return name if s >= min
    end
    "very_bad"
  end

  def tier_for(s)
    self.class.tier_for(s)
  end

  def tier
    self.class.tier_for(score)
  end

  def resyncing?
    @game&.resyncing?
  end

  def overlay?
    !score.nil?
  end

  # Left offset (%) for the needle + bubble. The 20 cells split 0–100 into
  # 5% slices, so instead of the raw score the needle snaps to the MIDDLE of
  # the 5% cell the score falls in: floor(score/5)*5 + 2.5. A 90–95 score
  # therefore lands at 92.5% — centred on its cell, which reads cleaner than
  # a needle pinned to the exact percent.
  CELL_WIDTH_PCT = 5

  def overlay_left_percent
    return nil if score.nil?

    s    = score.to_f.clamp(0.0, 100.0)
    cell = (s / CELL_WIDTH_PCT).floor.clamp(0, BAR_CELLS - 1)
    (cell * CELL_WIDTH_PCT) + (CELL_WIDTH_PCT / 2.0)
  end

  def fill_text
    "=" * BAR_CELLS
  end
end
