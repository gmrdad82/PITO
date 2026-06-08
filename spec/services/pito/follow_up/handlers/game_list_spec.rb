# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pito::FollowUp::Handlers::GameList do
  subject(:handler) { described_class.new }

  let(:conversation) { Conversation.singleton }
  let!(:game) { create(:game, title: "Lies of P") }

  it "registers for the game_list target in :append mode" do
    expect(described_class.target).to eq("game_list")
    expect(described_class.mode).to eq(:append)
  end

  it "appends the detail card AND the enhanced message for `show <id>` (mirrors the verb)" do
    result = handler.call(event: nil, rest: "show ##{game.id}", conversation: conversation)
    expect(result).to be_a(Pito::FollowUp::Result::Append)

    kinds = result.events.map { |e| e[:kind] }
    expect(kinds).to eq([ "system", "enhanced" ])

    detail = result.events.find { |e| e[:kind] == "system" }[:payload]
    expect(detail["body"]).to include("Lies of P")
    expect(detail["reply_target"]).to eq("game_detail")

    enhanced = result.events.find { |e| e[:kind] == "enhanced" }[:payload]
    expect(enhanced["body"]).to include("pito-game-enhanced-message")
  end

  it "resolves by title too" do
    result = handler.call(event: nil, rest: "show lies of p", conversation: conversation)
    expect(result.events.first[:payload]["body"]).to include("Lies of P")
  end

  it "appends a witty not-found for an unknown reference" do
    result = handler.call(event: nil, rest: "show 9999", conversation: conversation)
    expect(result.events.first[:payload]["text"]).to include("9999")
  end

  it "errors on an invalid action" do
    result = handler.call(event: nil, rest: "destroy 5", conversation: conversation)
    expect(result).to be_a(Pito::FollowUp::Result::Error)
  end

  it "spawns the same delete confirmation for `delete <id>`" do
    result = handler.call(event: nil, rest: "delete ##{game.id}", conversation: conversation)
    expect(result).to be_a(Pito::FollowUp::Result::Append)
    ev = result.events.first
    expect(ev[:kind]).to eq("confirmation")
    expect(ev[:payload]["command"]).to eq("game_delete")
    expect(ev[:payload]["game_id"]).to eq(game.id)
  end

  it "accepts `rm <id>` as an alias for delete" do
    result = handler.call(event: nil, rest: "rm ##{game.id}", conversation: conversation)
    expect(result.events.first[:kind]).to eq("confirmation")
  end

  it "stamps game_id in the appended detail event payload" do
    result = handler.call(event: nil, rest: "show ##{game.id}", conversation: conversation)
    payload = result.events.first[:payload]
    expect(payload["game_id"]).to eq(game.id)
  end
end
