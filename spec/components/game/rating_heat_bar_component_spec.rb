require "rails_helper"

# Reduced alias spec — asserts the deprecated shim still resolves and
# is a subclass of the canonical Pito::ScoreBarComponent. Full
# behavioral coverage lives in spec/components/pito/score_bar_component_spec.rb.
RSpec.describe Game::RatingHeatBarComponent, type: :component do
  it "is a subclass of Pito::ScoreBarComponent (alias still resolves)" do
    expect(described_class.superclass).to eq(Pito::ScoreBarComponent)
  end

  it "inherits BAR_CELLS from the canonical class" do
    expect(described_class::BAR_CELLS).to eq(Pito::ScoreBarComponent::BAR_CELLS)
  end

  it "inherits TIERS from the canonical class" do
    expect(described_class::TIERS).to eq(Pito::ScoreBarComponent::TIERS)
  end

  it "delegates synthesized_score to the canonical class method" do
    game = instance_double(
      Game,
      igdb_rating: 75, igdb_rating_count: 100,
      aggregated_rating: nil, aggregated_rating_count: nil,
      total_rating: nil, total_rating_count: nil
    )
    expect(described_class.synthesized_score(game)).to eq(75)
  end

  it "delegates tier_for to the canonical class method" do
    expect(described_class.tier_for(85)).to eq("good")
    expect(described_class.tier_for(nil)).to eq("missing")
  end
end
