# frozen_string_literal: true

require "rails_helper"

# Phase 18 contract: a verb reached via a `#<handle>` reply produces the SAME
# built+sent events as the same verb typed in free chat. The follow-up path runs
# the identical verb handler (T18.4) and only wraps the result (T18.3), so the
# events match modulo the per-message random reply_handle (not asserted here).
#
# This locks the contract for two representative verbs; per-verb detail-context
# parity (`#<handle> rm` with no ref) is added as each verb migrates in T19.
RSpec.describe "Chat ≡ #hashtag parity (Phase 18)", type: :service do
  let(:conversation) { Conversation.singleton }
  # A game_list source event — "show"/"delete" are its allowed reply actions.
  let(:game_list_event) { instance_double(Event, payload: { "reply_target" => "game_list" }) }
  let!(:game)           { create(:game, title: "Dead Space") }

  def free_events(input)
    Pito::Chat::Dispatcher.call(input:, conversation:).events
  end

  def reply_events(rest)
    Pito::FollowUp::VerbDelegator.call(source_event: game_list_event, rest:, conversation:).events
  end

  it "`show <id>` → same event kinds + same resolved game" do
    free  = free_events("show #{game.id}")
    reply = reply_events("show #{game.id}")

    expect(reply.map { |e| e[:kind] }).to eq(free.map { |e| e[:kind] })
    expect(reply.map { |e| e[:kind] }).to eq([ :system, :enhanced ])
    expect(reply.first[:payload].with_indifferent_access[:game_id])
      .to eq(free.first[:payload].with_indifferent_access[:game_id])
      .and eq(game.id)
  end

  it "`delete <id>` → same single confirmation event" do
    free  = free_events("delete #{game.id}")
    reply = reply_events("delete #{game.id}")

    expect(reply.map { |e| e[:kind].to_s }).to eq(free.map { |e| e[:kind].to_s })
    expect(reply.map { |e| e[:kind].to_s }).to eq([ "confirmation" ])
  end
end
