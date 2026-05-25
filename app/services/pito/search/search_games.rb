# Omnisearch local-corpus query against the shared `games_<env>`
# Meilisearch index that holds Game documents (written by
# `Game::MeilisearchIndexer`). The `kind` discriminator field is
# `"game"`.
#
# R1 (2026-05-25) — bundle documents removed; games only.
#
# Returns a Hash with one key:
#   - :games   → Array of Game ActiveRecord rows, ordered by
#                Meilisearch's relevance ranking.
#
# Options:
#   - limit: per-record-type cap. Defaults to 20.
#
# Network failures are logged and degrade to empty result sets so a
# Meilisearch hiccup never crashes the search controller path. The
# IGDB half of the omnisearch envelope is independent (see
# `Game::SearchService`) and continues even when the local half is
# empty.
require "net/http"
require "json"

module Pito
  module Search
    class SearchGames
      DEFAULT_LIMIT = 20

      def self.call(query, limit: DEFAULT_LIMIT, **_ignored)
        new(query, limit: limit).call
      end

      def initialize(query, limit: DEFAULT_LIMIT)
        @query = query.to_s.strip
        @limit = limit
      end

      def call
        return { games: [] } if @query.blank?

        hits = fetch_hits
        games = resolve_games(hits)

        # 2026-05-18 — Postgres ILIKE fallback ALWAYS merged in. The
        # user-reported bug (omnisearch local-results missing for
        # "street fighter" even though "Street Fighter 6" exists locally)
        # reproduces when Meilisearch returns SOME hits (so the prior
        # `if empty?` guard skipped fallback) but those hits don't
        # include a row whose title trivially matches via ILIKE — a
        # symptom of a stale or partially-populated index. Merging the
        # ILIKE fallback uniques after the Meilisearch ordering keeps
        # relevance ranking when the index is populated AND guarantees
        # the obvious substring matches always surface.
        games = merge_with_fallback(games, fallback_games)

        { games: games }
      rescue StandardError => e
        Rails.logger.warn("[Pito::Search::SearchGames] query failed (#{@query.inspect}): #{e.class}: #{e.message}")
        # Even on Meilisearch failure, attempt the Postgres fallback so
        # local games are still findable when the search engine is down.
        { games: fallback_games }
      end

      private

      # 2026-05-18 (Bug A fix) — short-query attribute restriction.
      # Meilisearch's default `searchableAttributes` includes
      # `title summary developer_name publisher_name genre_names`, and
      # `prefixSearch: indexingTime` makes every input act as a prefix
      # match. A 2-char query like "st" then matches "starts", "system",
      # "Steam", "studio", etc. inside `summary` / dev / pub / genre
      # fields and surfaces games whose titles have no "st" substring
      # at all (e.g. Pragmata's summary contains "starts").
      #
      # For short queries (<= SHORT_QUERY_THRESHOLD) we restrict the
      # search to the `title` attribute only via `attributesToSearchOn`.
      # That keeps "st" matching to actual title-prefix hits (Street
      # Fighter 6, Star Wars, Stellar Blade, ...) and drops the
      # summary-token noise. Longer queries (>= 4 chars) keep the full
      # attribute set so a user typing a developer / publisher / genre
      # name still gets hits via Meilisearch's default ranking.
      SHORT_QUERY_THRESHOLD = 3

      def fetch_hits
        url = ENV.fetch("MEILISEARCH_URL", "http://127.0.0.1:7727")
        uri = URI.parse("#{url}/indexes/#{index_name}/search")

        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/json"
        body = {
          q: @query,
          limit: @limit
        }
        # Short-query attribute restriction — see SHORT_QUERY_THRESHOLD.
        if @query.length <= SHORT_QUERY_THRESHOLD
          body[:attributesToSearchOn] = [ "title" ]
        end
        request.body = JSON.generate(body)

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", open_timeout: 2, read_timeout: 4) do |http|
          http.request(request)
        end

        return [] unless response.is_a?(Net::HTTPSuccess)
        JSON.parse(response.body).fetch("hits", [])
      end

      def index_name
        "games_#{Rails.env}"
      end

      # Pulls Game rows in Meilisearch hit order.
      def resolve_games(hits)
        game_ids = hits.select { |h| h["kind"] == "game" }.map { |h| h["id"] }.compact
        return [] if game_ids.empty?

        games_by_id = Game.where(id: game_ids).index_by(&:id)
        game_ids.map { |id| games_by_id[id] }.compact.first(@limit)
      end

      # Merges Meilisearch-ranked results (`primary`) with the Postgres
      # ILIKE fallback (`fallback`). Meilisearch ordering wins for the
      # leading entries; fallback rows whose id is not already in
      # `primary` are appended afterwards, capped at `@limit` total. This
      # guarantees the obvious substring matches always surface even
      # when the Meilisearch index is stale / partially populated, while
      # preserving Meilisearch's relevance ordering when the index is in
      # sync.
      def merge_with_fallback(primary, fallback)
        seen_ids = primary.map(&:id).to_set
        uniques = fallback.reject { |row| seen_ids.include?(row.id) }
        (primary + uniques).first(@limit)
      end

      # Postgres `LOWER(title) ILIKE %q%` OR `igdb_slug ILIKE %q-kebab%`
      # OR alt-name ILIKE fallback. Always consulted (and merged with the
      # Meilisearch hits via `merge_with_fallback`) so the obvious
      # substring matches surface even when the index is stale.
      #
      # Three columns matched:
      #
      #   1. `title`               — the IGDB `name` field as-persisted.
      #   2. `igdb_slug`           — IGDB canonical lowercased kebab-case slug.
      #   3. `alternative_names`   — Postgres text[] from IGDB alt-names.
      #
      # The result set is title-ordered so the fallback feels deterministic.
      def fallback_games
        title_like = "%#{Game.sanitize_sql_like(@query.downcase)}%"
        slug_like  = "%#{Game.sanitize_sql_like(@query.downcase.tr(' ', '-'))}%"
        Game.where(
          "LOWER(title) ILIKE :title_q OR LOWER(igdb_slug) ILIKE :slug_q OR EXISTS (SELECT 1 FROM unnest(alternative_names) AS alt WHERE LOWER(alt) ILIKE :title_q)",
          title_q: title_like, slug_q: slug_like
        ).order(:title).limit(@limit).to_a
      end
    end
  end
end
