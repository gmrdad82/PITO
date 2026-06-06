# frozen_string_literal: true

# Orchestrates the full 5-step IGDB import flow and streams progress + two
# chat messages back to the requesting conversation.
#
# Flow:
#   1. Resolve/create the Game record via `Game::Igdb::Importer`.
#   2. Broadcast Step 1 — "Fetching game info…" — then run `SyncGame` to
#      fetch + persist the full IGDB payload (main info + genres + companies).
#   3. Broadcast Step 2 — "Downloading cover art…" — SyncGame already
#      normalizes cover art synchronously; we re-fetch the game to pick it up.
#   4. Broadcast Step 3 — "Computing score…" — call `ScoreCalculator`.
#   5. After Step 3: stream the standard P9 game-detail chat message.
#   6. Broadcast Step 4 — "Indexing for recommendations…" — run
#      `Game::VoyageIndexer` synchronously (digest-gated, cheap if digest
#      matches — SyncGame already ran it async, so this may be a no-op).
#   7. Broadcast Step 5 — "Preparing recommendations…" — call dummy
#      `Pito::Recommendations.call` placeholder (real logic in P13).
#   8. After Step 5: stream the "enhanced" chat message stamped as
#      `game_enhanced` follow-up-able (handler comes in P12).
#
# Approach: **synchronous orchestration**.  All 5 stages run inline in this
# job (no sub-job fan-out).  `GameIgdbSync` enqueues `GameVoyageIndexJob`
# asynchronously after `SyncGame`; we do NOT rely on that async job here —
# we call `Game::VoyageIndexer.call` directly so the step-4 progress message
# is visible before the enhanced chat message is streamed.
#
# A Turn is created for the import so all emitted events are grouped under it
# in the scrollback.  The turn is completed (pito:done) at the end.
class GameImportJob < ApplicationJob
  queue_as :default

  def perform(igdb_id:, title:, conversation_id:)
    conversation = Conversation.find_by(id: conversation_id)
    return unless conversation

    broadcaster = Pito::Stream::Broadcaster.new(conversation:)

    # Create a turn so all events (progress + messages) land in one group.
    turn = conversation.turns.create!(
      position:   Turn.next_position_for(conversation),
      input_kind: :slash,
      input_text: "/games import #{title}".strip
    )

    # Echo the import invocation so the user sees what triggered the flow.
    echo_event = Event.create_with_position!(
      conversation:, turn:, kind: :echo,
      payload: { text: "/games import #{title}".strip, authenticated: true }
    )
    broadcaster.broadcast_event(echo_event)

    # Step 1 — Resolve/create Game + fetch IGDB main info
    emit_progress(broadcaster, turn:, conversation:, step: 1)

    result = Game::Igdb::Importer.call(igdb_id: igdb_id, title: title)
    game   = result[:game]

    # Run SyncGame synchronously so we have the full payload for step 2+.
    # `GameIgdbSync` (the standalone job) would also call SyncGame, but it
    # runs async — here we need it done before we proceed.
    game.update_column(:resyncing, true)
    begin
      Game::Igdb::SyncGame.new.call(game)
    rescue Game::Igdb::Client::ValidationError => e
      emit_error(broadcaster, turn:, conversation:, message: e.message)
      return
    ensure
      Game.where(id: game.id).update_all(resyncing: false)
    end
    game.reload

    # Step 2 — Cover art (already fetched by SyncGame above; just report it)
    emit_progress(broadcaster, turn:, conversation:, step: 2)

    # Step 3 — Score
    emit_progress(broadcaster, turn:, conversation:, step: 3)
    game.reload
    score = Pito::Game::ScoreCalculator.call(game)
    game.update_column(:score, score) if score != game.score

    # After Step 3 — stream the standard P9 detail message
    detail_payload = Pito::Game::DetailMessage.call(game.reload, conversation:)
    detail_event = Event.create_with_position!(
      conversation:, turn:, kind: :system,
      payload: detail_payload
    )
    broadcaster.broadcast_event(detail_event)

    # Step 4 — Voyage index (digest-gated; no-op if already fresh)
    emit_progress(broadcaster, turn:, conversation:, step: 4)
    begin
      ::Game::VoyageIndexer.call(game)
    rescue StandardError => e
      Rails.logger.warn("[GameImportJob] Voyage index failed for game id=#{game.id}: #{e.class}: #{e.message}")
    end

    # Step 5 — Recommendations (dummy placeholder; real logic in P13)
    emit_progress(broadcaster, turn:, conversation:, step: 5)
    Pito::Recommendations.call(game)

    # After Step 5 — stream the enhanced chat message stamped as game_enhanced
    enhanced_payload = {
      "body" => enhanced_body(game),
      "html" => true
    }
    Pito::FollowUp.make_followupable!(enhanced_payload, target: "game_enhanced", conversation:)

    enhanced_event = Event.create_with_position!(
      conversation:, turn:, kind: :system,
      payload: enhanced_payload
    )
    broadcaster.broadcast_event(enhanced_event)

    broadcaster.complete_turn(turn:)
  rescue StandardError => e
    handle_error(conversation, e)
    raise
  end

  private

  def emit_progress(broadcaster, turn:, conversation:, step:)
    label = I18n.t("pito.sidebar.games_import.progress.step#{step}")
    event = Event.create_with_position!(
      conversation:, turn:, kind: :system,
      payload: {
        "text"           => label,
        "import_step"    => step,
        "import_of"      => 5
      }
    )
    broadcaster.broadcast_event(event)
  end

  def emit_error(broadcaster, turn:, conversation:, message:)
    event = Event.create_with_position!(
      conversation:, turn:, kind: :error,
      payload: {
        text:   Pito::Copy.render("pito.copy.errors.dispatch_failed"),
        detail: message
      }
    )
    broadcaster.broadcast_event(event)
    broadcaster.complete_turn(turn:)
  end

  def enhanced_body(game)
    intro = Pito::Copy.render("pito.copy.games.enhanced_intro")
    intro_html = %(<p class="text-fg mb-2">#{ERB::Util.html_escape(intro)}</p>)
    %(<div class="pito-game-enhanced-message">#{intro_html}</div>)
  end

  def handle_error(conversation, error)
    return unless conversation
    broadcaster = Pito::Stream::Broadcaster.new(conversation:)
    Rails.logger.error("[GameImportJob] #{error.class}: #{error.message}")
  rescue StandardError
    nil
  end
end
