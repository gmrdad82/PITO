# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pito::Recommendation::Weights do
  it "blend weights sum to 1.0" do
    expect(described_class::BLEND.values.sum).to be_within(1e-9).of(1.0)
  end

  it "makes player-perspective the dominant single signal" do
    others = described_class::BLEND.except(:pp).values
    expect(described_class::PP).to be > others.max
  end

  it "ranks score > developer > publisher" do
    expect(described_class::S).to be > described_class::D
    expect(described_class::D).to be > described_class::P
  end

  describe ".blend" do
    it "returns 100 when every sub-score is 100" do
      expect(described_class.blend(e: 100, g: 100, t: 100, pp: 100, s: 100, d: 100, p: 100)).to eq(100)
    end

    it "returns 0 for an all-zero breakdown" do
      expect(described_class.blend(e: 0, g: 0, t: 0, pp: 0, s: 0, d: 0, p: 0)).to eq(0)
    end

    it "scores a perspective-only match higher than a genre-only match" do
      expect(described_class.blend(pp: 100)).to be > described_class.blend(g: 100)
    end

    it "scores a developer-only match higher than a publisher-only match" do
      expect(described_class.blend(d: 100)).to be > described_class.blend(p: 100)
    end

    it "scores a close-score-only match higher than developer or publisher alone" do
      expect(described_class.blend(s: 100)).to be > described_class.blend(d: 100)
      expect(described_class.blend(s: 100)).to be > described_class.blend(p: 100)
    end

    it "treats missing keys as zero (genre-only equals G × 100)" do
      expect(described_class.blend(g: 100)).to eq((described_class::G * 100).round)
    end
  end
end
