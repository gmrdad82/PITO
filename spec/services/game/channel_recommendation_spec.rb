# frozen_string_literal: true

require "rails_helper"

RSpec.describe Game::ChannelRecommendation, type: :service do
  def vec(index, value: 1.0)
    Array.new(1024, 0.0).tap { |a| a[index] = value }
  end

  let(:game) { create(:game, title: "Lies of P") }

  before { game.update_column(:summary_embedding, vec(0)) }

  it "returns [] for a nil game" do
    expect(described_class.call(nil)).to eq([])
  end

  it "returns [] when the game has no embedding" do
    game.update_column(:summary_embedding, nil)
    expect(described_class.call(game)).to eq([])
  end

  it "returns Result structs with channel, score, and distance" do
    channel = create(:channel, title: "Soulslike Central")
    channel.update_column(:summary_embedding, vec(0))

    results = described_class.call(game)
    expect(results.size).to eq(1)
    expect(results.first.channel).to eq(channel)
    expect(results.first.score).to eq(100)
    expect(results.first.distance).to be_within(0.0001).of(0.0)
  end

  it "drops channels below the score threshold" do
    near = create(:channel, title: "On-topic")
    near.update_column(:summary_embedding, vec(0))
    far = create(:channel, title: "Off-topic")
    far.update_column(:summary_embedding, vec(1)) # orthogonal → score 0

    results = described_class.call(game)
    expect(results.map(&:channel)).to eq([ near ])
  end

  it "skips channels without an embedding" do
    create(:channel, title: "Unindexed") # summary_embedding nil
    create(:channel, title: "Indexed").update_column(:summary_embedding, vec(0))

    expect(described_class.call(game).map { |r| r.channel.title }).to eq([ "Indexed" ])
  end
end
