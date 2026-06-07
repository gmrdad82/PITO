# frozen_string_literal: true

# Games best suited to a channel — the **channel→game** direction ("what should
# this channel cover next?"). Symmetric to Game::ChannelRecommendation: a game
# `g` suits channel `c` when `c` already covers games like `g`.
#
#   K  — `g` is linked to one of `c`'s videos → LINK_SCORE (100).
#   GG — best `GameSimilarity.between(g, linked_game)` across the games `c`
#        already covers (the same composition, the other way round).
#   E  — `c`'s top videos (by views) nearest `g` (cosine) — cold-start fallback.
#
#   game_score = max(K, GG, E), ranked best-first, floored at FLOOR.
#
# Candidate games = those sharing a genre/developer/publisher with any of `c`'s
# linked games, UNION the games nearest `c`'s probe videos. nil channel / no
# signal → `[]`.
class Channel
  class GameRecommendation
    FLOOR           = Pito::Recommendation::Weights::FLOOR
    LINK_SCORE      = Pito::Recommendation::Weights::LINK_SCORE
    TOP_VIDEOS      = 10 # top videos by views used to probe games
    GAMES_PER_VIDEO = 8  # nearest games fetched per probe video

    Result = Struct.new(:game, :score, :breakdown, keyword_init: true)

    def self.call(channel, limit: nil)
      new(channel, limit: limit).call
    end

    def initialize(channel, limit: nil)
      @channel = channel
      @limit   = limit
    end

    def call
      return [] if @channel.nil?

      linked     = linked_games
      e_by_game  = embedding_scores # game_id => best E (also the embedding candidates)
      candidates = candidate_games(linked, e_by_game.keys)
      return [] if candidates.empty?

      linked_ids = linked.map(&:id).to_set

      ranked = candidates.filter_map { |game|
        k  = linked_ids.include?(game.id) ? LINK_SCORE.to_f : 0.0
        gg = linked.map { |lg| Pito::Recommendation::GameSimilarity.between(game, lg)[:score] }.max || 0.0
        e  = e_by_game[game.id] || 0.0
        score = [ k, gg, e ].max.round
        next if score < FLOOR

        Result.new(game: game, score: score, breakdown: nil)
      }.sort_by { |result| [ -result.score, result.game.id ] }

      @limit ? ranked.first(@limit) : ranked
    end

    private

    # Games the channel already covers (via its videos' explicit links), with
    # facets preloaded for GameSimilarity.between.
    def linked_games
      ids = ::VideoGameLink.joins(:video).where(videos: { channel_id: @channel.id }).distinct.pluck(:game_id)
      return [] if ids.empty?

      ::Game.where(id: ids).includes(:genres, :developer_companies, :publisher_companies).to_a
    end

    def candidate_games(linked, embedding_ids)
      ids = (facet_candidate_ids(linked) + embedding_ids + linked.map(&:id)).uniq
      return [] if ids.empty?

      ::Game.where(id: ids).includes(:genres, :developer_companies, :publisher_companies).to_a
    end

    # Games sharing >= 1 genre / developer / publisher with any covered game.
    def facet_candidate_ids(linked)
      genre_ids = linked.flat_map { |g| g.genres.map(&:id) }.uniq
      dev_ids   = linked.flat_map { |g| g.developer_companies.map(&:id) }.uniq
      pub_ids   = linked.flat_map { |g| g.publisher_companies.map(&:id) }.uniq

      ids = []
      ids += join_pool(:game_genres, :genre_id, genre_ids)
      ids += join_pool(:game_developers, :company_id, dev_ids)
      ids += join_pool(:game_publishers, :company_id, pub_ids)
      ids.uniq
    end

    def join_pool(join, column, values)
      return [] if values.blank?

      ::Game.joins(join).where(join => { column => values }).distinct.pluck(:id)
    end

    # E — best video→game embedding similarity, keyed by game id. Probes the
    # channel's top videos by views (materialized in `stats`).
    def embedding_scores
      scores = Hash.new(0.0)
      probe_videos.each do |video|
        nearest_games(video).each do |game|
          e = Pito::Recommendation::Signals.embedding(game.neighbor_distance)
          scores[game.id] = e if e > scores[game.id]
        end
      end
      scores
    end

    def probe_videos
      @channel.videos
        .where.not(summary_embedding: nil)
        .joins("LEFT JOIN stats ON stats.entity_type = 'Video' AND stats.entity_id = videos.id AND stats.kind = 'views'")
        .order(Arel.sql("COALESCE(stats.value, 0) DESC"))
        .limit(TOP_VIDEOS)
    end

    def nearest_games(video)
      ::Game
        .where.not(summary_embedding: nil)
        .nearest_neighbors(:summary_embedding, video.summary_embedding, distance: "cosine")
        .first(GAMES_PER_VIDEO)
    end
  end
end
