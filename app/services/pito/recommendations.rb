# frozen_string_literal: true

module Pito
  # Placeholder facade for the recommendations engine.
  #
  # The real 3-way recommendation methods (`similar_games`, `channels_for`,
  # `games_for`) are implemented in P13 using `SimilarGames`,
  # `Game::ChannelRecommendation`, and `Channel::GameRecommendation`.
  #
  # Import step 5 (`GameImportJob`) calls `Pito::Recommendations.call` as a
  # dummy warm-up so the progress sequence has a Step 5 to broadcast.  The
  # actual recommendation payloads land in P12/P13 follow-ups.
  #
  # NOTE: this placeholder is intentionally kept distinct from the real P13
  # implementation.  When P13 lands, the full method signatures (`similar_games`,
  # `channels_for`, `games_for`) are added here; the `call` stub below stays as
  # the job's dummy probe.
  module Recommendations
    module_function

    # Dummy step-5 probe used by GameImportJob.
    # Returns true unconditionally so the job can broadcast "Recommendations ready."
    # without actually computing anything.  Real logic lives in P13.
    def call(*) = true
  end
end
