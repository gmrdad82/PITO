# Recommendation engine: game ↔ channel (both ways) + game ↔ game

> Status: Drafting — not signed off. Implementation waits for explicit go-ahead.

## Sign-off

- [x] Drafted
- [ ] Audited

## North star

One coherent, multi-signal recommendation engine across three directions, each
returning `Result` structs (entity, 0–100 score, debug breakdown), ranked
best-first, floored at 25. Channels have **no embedding** (Design B): a channel
IS its videos, so every channel signal is derived by traversing
`channel → videos → (embedding | linked games → genres)`. Each direction is one
**smart SQL query** (CTEs, no N+1 HNSW loops in Ruby) that blends the signals
into a single score, then a thin Ruby wrapper builds `Result`s. Every signal is
independently spec'd, in isolation and in combination.

## Why this rewrite (the missing thing)

A channel with 6 Pragmata videos scored only 75 (best video's cosine sim) until
the videos were explicitly linked to the game. The engine must reason over the
**relationship graph**, not just text embeddings: `video → linked game →
genre`, grouped up to the channel. Today's services miss most of this:

| Direction | Service | Has now | Missing |
|---|---|---|---|
| game→channel | `Game::ChannelRecommendation` | embedding + explicit link | linked-game **genre / developer / publisher / score** overlap; single-query form |
| channel→game | `Channel::GameRecommendation` | embedding (top videos) | explicit **link**; **genre / developer / publisher / score** overlap |
| game→game | `Game::SimilarGames` | embedding only | **genre / developer / publisher / score** blended into the score (today they are only post-filters in `Pito::Recommendations`) |

## Signal catalogue

Each signal yields a 0–100 sub-score; the final score is a weighted blend
(weights in §Weighting), with explicit links overriding to 100.

- **E (embedding)** — `(1 - cosine_distance) * 100` between two `summary_embedding`s.
- **K (explicit link)** — a `video_game_links` row ties a video to a game.
  Definitive, human-asserted → contributes 100 (overrides the blend).
- **G (genre overlap)** — Jaccard over genre sets × 100 (shared / union).
- **D (developer overlap)** — shares ≥1 developer company → Jaccard × 100.
- **P (publisher overlap)** — shares ≥1 publisher company → Jaccard × 100.
- **S (score proximity)** — `(1 - abs(a.score - b.score) / 100) * 100`.

### game → channel (recommend channels for game `g`)

The whole chain is connected: `channel → videos → linked games →
{genre, developer, publisher, score}`. Per channel, aggregate across its videos
and the games those videos are linked to, then take the strongest:

- K: channel owns a video linked to `g` → 100.
- E: max over the channel's videos of `embed(video, g)`.
- G/D/P/S: over the games linked to the channel's videos, the best
  genre / developer / publisher / score-proximity overlap with `g`
  (`channel → videos → video_game_links → games → {game_genres, game_developers, game_publishers, score}`).

`channel_score = GREATEST(100·has_link, w_E·E + w_G·G + w_D·D + w_P·P + w_S·S)`

### channel → game (recommend games for channel `c`)

Symmetric — per candidate game `g`, across the channel's (top-by-views) videos
and the games already linked to them:

- K: `g` is linked to one of `c`'s videos → 100.
- E: max over `c`'s probe videos of `embed(video, g)`.
- G/D/P/S: `g`'s genre / developer / publisher / score overlap with the games
  already linked to `c`'s videos.

`game_score = GREATEST(100·has_link, w_E·E + w_G·G + w_D·D + w_P·P + w_S·S)`

### game → game (similar games to `g`)

- E: `embed(g, g')`.
- G / D / P: genre / developer / publisher Jaccard.
- S: score proximity.

`sim_score = w_E·E + w_G·G + w_D·D + w_P·P + w_S·S`

## The smart query (design sketch — game → channel)

One query, no Ruby-side HNSW loop:

```sql
WITH target AS (
  SELECT summary_embedding, ARRAY(
    SELECT genre_id FROM game_genres WHERE game_id = :game_id
  ) AS genre_ids
  FROM games WHERE id = :game_id
),
per_video AS (
  SELECT v.channel_id,
         1 - (v.summary_embedding <=> (SELECT summary_embedding FROM target)) AS e,
         bool_or(vgl.game_id = :game_id) AS linked,
         -- genre overlap of this video's OTHER linked games with the target
         coalesce(max(genre_jaccard(lg_genres.ids, (SELECT genre_ids FROM target))), 0) AS g
  FROM videos v
  LEFT JOIN video_game_links vgl ON vgl.video_id = v.id
  LEFT JOIN LATERAL (
    SELECT ARRAY(SELECT genre_id FROM game_genres WHERE game_id = vgl.game_id) AS ids
  ) lg_genres ON true
  WHERE v.summary_embedding IS NOT NULL OR vgl.game_id IS NOT NULL
  GROUP BY v.id, v.channel_id, v.summary_embedding
)
SELECT channel_id,
       GREATEST(100 * bool_or(linked)::int,
                (:w_e * max(e) + :w_g * max(g)))::int AS score
FROM per_video
GROUP BY channel_id
HAVING GREATEST(...) >= :floor
ORDER BY score DESC;
```

`genre_jaccard` is a small SQL helper (or inlined `array_intersect/union`
length math); developer/publisher overlap reuse it over company-id arrays, and
score proximity is `1 - abs(diff)/100`. The `per_video` CTE therefore also pulls
each linked game's developer/publisher company ids and `score`, and the final
`GREATEST` blends `w_E·E + w_G·G + w_D·D + w_P·P + w_S·S`. The channel→game and
game→game queries follow the same CTE shape.

## Decisions needing confirmation

- **DR1 — Signal weights (one unified set, all directions).** Tunable, in
  `Pito::Recommendation::Weights`. Reflects the stated ranking — embedding
  primary, genre strong, **score counts MORE**, **developer counts for
  something**, **publisher counts LESS**:
  `w_E=0.45` (embedding), `w_G=0.20` (genre), `w_S=0.15` (score proximity),
  `w_D=0.12` (developer), `w_P=0.08` (publisher). Sum = 1.0. Explicit link
  overrides the blend to 100. Confirm the ordering (S > D > P) and exact values.
- **DR2 — Genre overlap metric.** Jaccard (shared/union) vs raw shared-count.
  Recommend Jaccard (bounded 0–1). Confirm.
- **DR3 — Floor stays 25** across all three directions (matches game-score "bad"
  tier). Confirm.

## Locked decisions

- LR1 — Runs on `beta-videos`, current branch; never drop the DB.
- LR2 — One query per direction (CTEs); Ruby only builds `Result`s.
- LR3 — Explicit `video_game_links` always override the blend to 100.
- LR4 — `Result` gains a `breakdown:` hash (`{e:, k:, g:, d:, p:, s:}`) so specs
  and the UI can assert/show *why* something ranked where it did.
- LR5 — Weights centralised in `Pito::Recommendation::Weights`.
- LR6 — **Operating assumption: every video is linked to its game(s)** (the user
  always links them). So the link graph is the **primary** signal: the facet
  overlaps (G/D/P/S) are computed via reliably-present `video → linked game`
  edges and do the real discrimination, while embedding (E) is the **fallback /
  cold-start** signal for not-yet-linked content. Specs must cover the
  fully-linked path as the common case, not the exception.

## Phase index

- Phase R1 — Shared scaffolding (Weights, genre/dev/publisher Jaccard helpers, Result breakdown)
- Phase R2 — game→channel multi-signal query
- Phase R3 — channel→game multi-signal query
- Phase R4 — game→game multi-signal score
- Phase R5 — Exhaustive spec coverage (all directions, each signal)
- Phase R6 — Wire surfaces + debug breakdown rendering

---

## Phase R1 — Shared scaffolding

- [ ] TR1.1 Add `Pito::Recommendation::Weights` constants module (DR1 values). complexity: [low]
- [ ] TR1.2 Add a `genre_jaccard(game_a, game_b)` helper (Ruby + SQL form). complexity: [high]
- [ ] TR1.3 Add `company_jaccard` for developer + publisher sets. complexity: [low]
- [ ] TR1.4 Add `score_proximity(a, b)` helper. complexity: [low]
- [ ] TR1.5 Extend every `Result` struct with a `breakdown:` hash. complexity: [low]
- [ ] TR1.6 Spec each helper in isolation (empty sets, full overlap, partial). complexity: [high]
- [ ] TR1.7 Run helper specs; make green. complexity: [low]
- [ ] TR1.8 Commit: "Add recommendation scaffolding (weights + signal helpers)". complexity: [manual]

## Phase R2 — game → channel multi-signal query

- [ ] TR2.1 Write the CTE query (embedding + link) in `Game::ChannelRecommendation`. complexity: [high]
- [ ] TR2.1a Add linked-game genre overlap (G) to the CTE. complexity: [high]
- [ ] TR2.1b Add linked-game developer overlap (D) to the CTE. complexity: [high]
- [ ] TR2.1c Add linked-game publisher overlap (P) to the CTE. complexity: [high]
- [ ] TR2.1d Add linked-game score-proximity (S) to the CTE. complexity: [high]
- [ ] TR2.2 Blend signals with `Weights` and map rows to `Result` with `breakdown`. complexity: [high]
- [ ] TR2.3 Apply the 25 floor + best-first sort + optional limit. complexity: [low]
- [ ] TR2.4 Keep link override (linked channel = 100) in SQL via GREATEST. complexity: [high]
- [ ] TR2.5 Add a DB index review note for the join columns (`video_game_links`, `game_genres`). complexity: [low]
- [ ] TR2.6 Run game→channel specs (Phase R5 subset); make green. complexity: [low]
- [ ] TR2.7 Commit: "game→channel: blend embedding + link + genre in one query". complexity: [manual]

## Phase R3 — channel → game multi-signal query

- [ ] TR3.1 Write the CTE query (top-video embedding) in `Channel::GameRecommendation`. complexity: [high]
- [ ] TR3.2 Add the explicit-link signal (game linked to channel's videos → 100). complexity: [high]
- [ ] TR3.3 Add genre overlap (G) vs games already linked to the channel. complexity: [high]
- [ ] TR3.3a Add developer (D) + publisher (P) overlap vs the channel's linked games. complexity: [high]
- [ ] TR3.3b Add score-proximity (S) vs the channel's linked games. complexity: [high]
- [ ] TR3.4 Blend with `Weights`; map rows to `Result` with `breakdown`; floor + sort + limit. complexity: [low]
- [ ] TR3.5 Run channel→game specs; make green. complexity: [low]
- [ ] TR3.6 Commit: "channel→game: blend embedding + link + genre". complexity: [manual]

## Phase R4 — game → game multi-signal score

- [ ] TR4.1 Write the CTE query blending E + G + D + P + S in `Game::SimilarGames`. complexity: [high]
- [ ] TR4.2 Exclude the input game; skip rows with no embedding AND no shared facets. complexity: [low]
- [ ] TR4.3 Map rows to `Result` with `breakdown`; floor + sort + limit. complexity: [low]
- [ ] TR4.4 Keep `Pito::Recommendations.similar_games` filters working over the new scorer. complexity: [high]
- [ ] TR4.5 Run game→game specs; make green. complexity: [low]
- [ ] TR4.6 Commit: "game→game: blend embedding + genre + dev + publisher + score". complexity: [manual]

## Phase R5 — Exhaustive spec coverage

Each scenario uses fixed unit vectors + controlled genres/companies/scores so
the expected blended score is deterministic.

- [ ] TR5.1 game→channel: explicit link → score 100 regardless of embedding. complexity: [low]
- [ ] TR5.2 game→channel: embedding-only channel scores its best video's sim. complexity: [low]
- [ ] TR5.3 game→channel: genre-only overlap (linked to a same-genre OTHER game) scores via G. complexity: [high]
- [ ] TR5.3a game→channel: developer overlap via a linked game contributes D. complexity: [high]
- [ ] TR5.3b game→channel: publisher overlap contributes P (and less than D for equal overlap). complexity: [high]
- [ ] TR5.3c game→channel: score-proximity via a linked game contributes S (and more than P). complexity: [high]
- [ ] TR5.4 game→channel: link beats a higher embedding on another channel (ordering). complexity: [low]
- [ ] TR5.5 game→channel: every channel above floor returned, none capped. complexity: [low]
- [ ] TR5.6 game→channel: channel with only sub-floor signals is dropped. complexity: [low]
- [ ] TR5.7 game→channel: multiple videos in one channel collapse to its best signal. complexity: [low]
- [ ] TR5.8 channel→game: explicit link → game scores 100. complexity: [low]
- [ ] TR5.9 channel→game: embedding via top-by-views probe videos. complexity: [high]
- [ ] TR5.10 channel→game: genre / developer / publisher / score overlap with already-linked games each contributes. complexity: [high]
- [ ] TR5.10a weights ordering holds: equal-magnitude overlaps rank S > D > P. complexity: [high]
- [ ] TR5.11 channel→game: floor + sort + limit honored. complexity: [low]
- [ ] TR5.12 game→game: identical embedding → ~100. complexity: [low]
- [ ] TR5.13 game→game: shared genre raises score vs embedding-only. complexity: [low]
- [ ] TR5.14 game→game: shared developer contributes D. complexity: [low]
- [ ] TR5.15 game→game: shared publisher contributes P. complexity: [low]
- [ ] TR5.16 game→game: close scores add S; far scores don't. complexity: [low]
- [ ] TR5.17 game→game: `breakdown` sums to the reported score under the weights. complexity: [high]
- [ ] TR5.18 all directions: nil / unembedded / no-data input → `[]`. complexity: [low]
- [ ] TR5.19 Run the full recommendation spec suite; make green. complexity: [low]
- [ ] TR5.20 Commit: "Exhaustive recommendation specs (3 directions, every signal)". complexity: [manual]

## Phase R6 — Wire surfaces + debug breakdown

- [ ] TR6.1 Confirm the enhanced game message uses the new game→channel results. complexity: [low]
- [ ] TR6.2 Confirm `show game` similar-games shelf uses the new game→game results. complexity: [low]
- [ ] TR6.3 Add a channel→game surface (recommendations on a channel view/command). complexity: [high]
- [ ] TR6.4 Optionally expose `breakdown` behind a debug flag in the score bar tooltip. complexity: [high]
- [ ] TR6.5 Run the surface/component specs; make green. complexity: [low]
- [ ] TR6.6 Commit: "Wire multi-signal recommendations into all surfaces". complexity: [manual]
