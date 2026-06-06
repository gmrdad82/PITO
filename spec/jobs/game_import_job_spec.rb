# frozen_string_literal: true

require "rails_helper"
require "action_cable/test_helper"

RSpec.describe GameImportJob, type: :job do
  include ActionCable::TestHelper

  # ── Shared setup ─────────────────────────────────────────────────────────────

  let(:conversation)    { Conversation.create! }
  let(:igdb_id)         { 1020 }
  let(:title)           { "Lies of P" }
  let(:game)            { create(:game, igdb_id: igdb_id, title: title) }

  # Stub SyncGame so we don't hit the IGDB API
  let(:sync_game_double) { instance_double(Game::Igdb::SyncGame, call: game) }

  before do
    # Stub SyncGame
    allow(Game::Igdb::SyncGame).to receive(:new).and_return(sync_game_double)
    allow(sync_game_double).to receive(:call) { game.update_column(:igdb_synced_at, Time.current); game }

    # Stub Importer (covers both import + resync paths)
    allow(Game::Igdb::Importer).to receive(:call).with(igdb_id: igdb_id, title: title)
                                                 .and_return({ game: game, action: :import })

    # Stub VoyageIndexer (skips actual Voyage HTTP call)
    allow(::Game::VoyageIndexer).to receive(:call)

    # Stub ScoreCalculator
    allow(Pito::Game::ScoreCalculator).to receive(:call).and_return(80.0)

    # Stub DetailMessage
    allow(Pito::Game::DetailMessage).to receive(:call)
      .and_return({ "body" => "<div>detail</div>", "html" => true })

    # Stub update_column for all column names (resyncing, score, igdb_synced_at, etc.)
    allow(game).to receive(:update_column).with(anything, anything)
    allow(game).to receive(:reload).and_return(game)
    allow(Game).to receive(:where).and_call_original
    allow(Game).to receive(:where).with(id: game.id).and_return(
      double(update_all: nil)
    )
  end

  def perform
    described_class.new.perform(
      igdb_id:         igdb_id,
      title:           title,
      conversation_id: conversation.id
    )
  end

  # ── No-op guard ──────────────────────────────────────────────────────────────

  it "is a no-op when the conversation does not exist" do
    expect { described_class.new.perform(igdb_id:, title:, conversation_id: 0) }
      .not_to raise_error
  end

  # ── Step broadcasts ──────────────────────────────────────────────────────────

  it "broadcasts 5 progress events (one per step)" do
    perform
    step_events = conversation.events.where("payload->>'import_step' IS NOT NULL")
    expect(step_events.count).to eq(5)
    expect(step_events.map { |e| e.payload["import_step"] }.sort).to eq([ 1, 2, 3, 4, 5 ])
  end

  it "broadcasts a detail message event (html: true, after step 3)" do
    perform
    detail = conversation.events.find { |e| e.payload["html"] == true && e.payload["body"]&.include?("detail") }
    expect(detail).to be_present
  end

  it "broadcasts an enhanced message event (html: true, game_enhanced followup)" do
    perform
    enhanced = conversation.events.find { |e|
      e.payload["html"] == true && e.payload["reply_target"] == "game_enhanced"
    }
    expect(enhanced).to be_present
  end

  it "calls Game::Igdb::Importer with the correct igdb_id and title" do
    expect(Game::Igdb::Importer).to receive(:call).with(igdb_id: igdb_id, title: title)
    perform
  end

  it "calls Game::Igdb::SyncGame#call" do
    expect(sync_game_double).to receive(:call)
    perform
  end

  it "calls Game::VoyageIndexer for step 4" do
    expect(::Game::VoyageIndexer).to receive(:call)
    perform
  end

  it "completes the turn (sets completed_at)" do
    perform
    turn = conversation.turns.last
    expect(turn.completed_at).to be_present
  end

  # ── Resync path (already-in-library) ─────────────────────────────────────────

  context "when game already exists in library (resync)" do
    before do
      allow(Game::Igdb::Importer).to receive(:call).with(igdb_id: igdb_id, title: title)
                                                   .and_return({ game: game, action: :resync })
    end

    it "still runs all 5 steps" do
      perform
      step_events = conversation.events.where("payload->>'import_step' IS NOT NULL")
      expect(step_events.count).to eq(5)
    end

    it "still streams both messages" do
      perform
      detail   = conversation.events.find { |e| e.payload["html"] == true && e.payload["body"]&.include?("detail") }
      enhanced = conversation.events.find { |e| e.payload["reply_target"] == "game_enhanced" }
      expect(detail).to be_present
      expect(enhanced).to be_present
    end
  end
end
