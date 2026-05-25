require "rails_helper"

RSpec.describe Pito::ScoreBarComponent, type: :component do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def game_double(igdb: nil, igdb_count: nil, agg: nil, agg_count: nil,
                   total: nil, total_count: nil, resyncing: false)
    instance_double(
      Game,
      igdb_rating: igdb,
      igdb_rating_count: igdb_count,
      aggregated_rating: agg,
      aggregated_rating_count: agg_count,
      total_rating: total,
      total_rating_count: total_count,
      resyncing?: resyncing
    )
  end

  # ---------------------------------------------------------------------------
  # Class-level helpers — synthesized_score
  # ---------------------------------------------------------------------------

  describe ".synthesized_score" do
    subject(:score) { described_class.synthesized_score(game) }

    context "when game is nil" do
      let(:game) { nil }

      it { is_expected.to be_nil }
    end

    context "when no rating triplet has a positive count" do
      let(:game) { game_double(igdb: 80, igdb_count: 0) }

      it { is_expected.to be_nil }
    end

    context "when only igdb_rating is present" do
      let(:game) { game_double(igdb: 80, igdb_count: 100) }

      it "returns the igdb score rounded" do
        expect(score).to eq(80)
      end
    end

    context "when multiple triplets contribute" do
      let(:game) do
        game_double(igdb: 80, igdb_count: 100,
                    agg: 60, agg_count: 50)
      end

      it "returns the vote-weighted average" do
        # (80*100 + 60*50) / 150 = 11000/150 = 73.33 → 73
        expect(score).to eq(73)
      end
    end

    context "when all three triplets contribute" do
      let(:game) do
        game_double(igdb: 90, igdb_count: 200,
                    agg: 70, agg_count: 100,
                    total: 80, total_count: 50)
      end

      it "returns the vote-weighted average of all three sources" do
        # (90*200 + 70*100 + 80*50) / 350 = (18000+7000+4000)/350 = 29000/350 ≈ 82.86 → 83
        expect(score).to eq(83)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Class-level helpers — tier_for
  # ---------------------------------------------------------------------------

  describe ".tier_for" do
    {
      nil  => "missing",
      100  => "excellent",
      90   => "excellent",
      89   => "good",
      80   => "good",
      79   => "fair",
      70   => "fair",
      69   => "meh",
      60   => "meh",
      59   => "poor",
      50   => "poor",
      49   => "bad",
      25   => "bad",
      24   => "very_bad",
      0    => "very_bad"
    }.each do |input, expected|
      it "maps #{input.inspect} → #{expected}" do
        expect(described_class.tier_for(input)).to eq(expected)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # BAR_CELLS constant
  # ---------------------------------------------------------------------------

  describe "BAR_CELLS" do
    it "is 60" do
      expect(described_class::BAR_CELLS).to eq(60)
    end
  end

  # ---------------------------------------------------------------------------
  # Instance — score / override
  # ---------------------------------------------------------------------------

  describe "#score" do
    context "when an explicit score override is provided" do
      subject(:comp) { described_class.new(score: 77) }

      it "returns the override without consulting the game" do
        expect(comp.score).to eq(77)
      end
    end

    context "when no override is given and a game is present" do
      let(:game) { game_double(igdb: 85, igdb_count: 200) }

      subject(:comp) { described_class.new(game: game) }

      it "synthesizes the score from the game's rating triplets" do
        expect(comp.score).to eq(85)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Instance — overlay?
  # ---------------------------------------------------------------------------

  describe "#overlay?" do
    it "is false when score is nil" do
      comp = described_class.new(game: game_double)
      expect(comp.overlay?).to be false
    end

    it "is false when game is resyncing" do
      game = game_double(igdb: 80, igdb_count: 50, resyncing: true)
      comp = described_class.new(game: game)
      expect(comp.overlay?).to be false
    end

    it "is true when score present and not resyncing" do
      game = game_double(igdb: 80, igdb_count: 50, resyncing: false)
      comp = described_class.new(game: game)
      expect(comp.overlay?).to be true
    end
  end

  # ---------------------------------------------------------------------------
  # Instance — overlay_left_percent
  # ---------------------------------------------------------------------------

  describe "#overlay_left_percent" do
    it "returns nil when score is nil" do
      comp = described_class.new(game: game_double)
      expect(comp.overlay_left_percent).to be_nil
    end

    it "clamps the score to 0..100" do
      comp = described_class.new(score: 50)
      expect(comp.overlay_left_percent).to eq(50.0)
    end
  end

  # ---------------------------------------------------------------------------
  # Instance — fill_text
  # ---------------------------------------------------------------------------

  describe "#fill_text" do
    it "returns a string of 60 = characters" do
      comp = described_class.new
      expect(comp.fill_text).to eq("=" * 60)
    end
  end

  # ---------------------------------------------------------------------------
  # Rendering — muted variant (no score, no game)
  # ---------------------------------------------------------------------------

  describe "rendering" do
    context "muted variant (nil score)" do
      subject(:rendered) { render_inline(described_class.new) }

      it "renders the muted CSS hooks" do
        expect(rendered.css(".rating-heat-bar--muted, .pito-score-bar--muted").first).to be_present
      end

      it "carries both the legacy and canonical root CSS hooks" do
        root = rendered.css(".rating-heat-bar.pito-score-bar").first
        expect(root).to be_present
      end

      it "does not render a tick or bubble" do
        expect(rendered.css(".rating-heat-bar__tick, .pito-score-bar__tick")).to be_empty
        expect(rendered.css(".rating-heat-bar__bubble, .pito-score-bar__bubble")).to be_empty
      end

      it "emits data-tier=missing" do
        root = rendered.css("[data-tier]").first
        expect(root["data-tier"]).to eq("missing")
      end
    end

    context "scored variant" do
      let(:game) { game_double(igdb: 87, igdb_count: 150) }

      subject(:rendered) { render_inline(described_class.new(game: game)) }

      it "carries both root CSS hooks" do
        root = rendered.css(".rating-heat-bar.pito-score-bar").first
        expect(root).to be_present
      end

      it "emits data-score with the synthesized score" do
        root = rendered.css("[data-score]").first
        expect(root["data-score"]).to eq("87")
      end

      it "emits data-tier reflecting the score" do
        root = rendered.css("[data-tier]").first
        expect(root["data-tier"]).to eq("good")
      end

      it "emits data-resyncing=no" do
        root = rendered.css("[data-resyncing]").first
        expect(root["data-resyncing"]).to eq("no")
      end

      it "renders a tick overlay" do
        expect(rendered.css(".rating-heat-bar__tick, .pito-score-bar__tick").first).to be_present
      end

      it "renders a bubble overlay with the numeric score" do
        bubble_num = rendered.css(".rating-heat-bar__bubble-num, .pito-score-bar__bubble-num").first
        expect(bubble_num).to be_present
        expect(bubble_num.text.strip).to eq("87")
      end

      it "sets left: on the tick matching the score percent" do
        tick = rendered.css(".rating-heat-bar__tick, .pito-score-bar__tick").first
        expect(tick["style"]).to include("left: 87.0%")
      end
    end

    context "resyncing variant" do
      let(:game) { game_double(igdb: 80, igdb_count: 100, resyncing: true) }

      subject(:rendered) { render_inline(described_class.new(game: game)) }

      it "emits data-resyncing=yes" do
        root = rendered.css("[data-resyncing]").first
        expect(root["data-resyncing"]).to eq("yes")
      end

      it "does not render a tick or bubble while resyncing" do
        expect(rendered.css(".rating-heat-bar__tick, .pito-score-bar__tick")).to be_empty
        expect(rendered.css(".rating-heat-bar__bubble, .pito-score-bar__bubble")).to be_empty
      end
    end

    context "explicit score override" do
      subject(:rendered) { render_inline(described_class.new(score: 42)) }

      it "uses the override score in data-score" do
        root = rendered.css("[data-score]").first
        expect(root["data-score"]).to eq("42")
      end

      it "derives tier from the override score" do
        root = rendered.css("[data-tier]").first
        expect(root["data-tier"]).to eq("poor")
      end
    end
  end
end
