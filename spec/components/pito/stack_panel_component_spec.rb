require "rails_helper"

RSpec.describe Pito::StackPanelComponent, type: :component do
  let(:postgres_status) { { connected: true, version: "16.0" } }
  let(:redis_status)    { { connected: true } }
  let(:storage_status)  { { present: true, writable: true } }
  let(:search_stats)    { {} }

  let(:component) do
    described_class.new(
      postgres_status: postgres_status,
      postgres_table_breakdown: [],
      search_healthy: true,
      search_stats: search_stats,
      search_per_index_stats: [],
      voyage_configured: true,
      storage_status: storage_status,
      assets_breakdown: [],
      sidekiq_breakdown: [],
      redis_status: redis_status
    )
  end

  describe "PANEL_NAME" do
    it "matches the canonical Pito::PanelChannel allowlist entry" do
      expect(described_class::PANEL_NAME).to eq(:stack)
      expect(Pito::PanelChannel::ALLOWED_PANELS).to include(described_class::PANEL_NAME.to_s)
    end
  end

  it "no longer defines the legacy CABLE_CHANNEL constant (Phase 2C cleanup)" do
    expect(described_class.const_defined?(:CABLE_CHANNEL)).to be(false)
  end

  describe "#cable_channel_for" do
    it "derives the canonical pito:home:stack stream name" do
      expect(component.cable_channel_for(described_class::PANEL_NAME)).to eq("pito:home:stack")
    end
  end

  describe "#title" do
    it "resolves from the canonical home-panel i18n namespace" do
      expect(I18n.t("tui.home.panels.stack.title")).to eq("stack")
      expect(component.title).to eq("stack")
    end
  end

  describe "#panel_data (data attrs spread into the section root)" do
    # Stub focusables so we don't need to drive the live sub-panel
    # helpers chain — the contract under test here is the data-attr
    # emission shape, not the focusables computation.
    before { allow(component).to receive(:focusables).and_return([]) }

    let(:data) { component.panel_data[:data] }

    it "wires the tui-panel-cable Stimulus controller" do
      expect(data[:controller]).to eq("tui-panel-cable")
    end

    it "emits the canonical cable name + screen data values" do
      expect(data[:tui_panel_cable_name_value]).to eq("stack")
      expect(data[:tui_panel_cable_screen_value]).to eq("home")
    end

    it "registers the panel as a tui-cursor target" do
      expect(data[:tui_cursor_target]).to eq("panel")
    end

    it "emits the panel name into both cable + panel scope data values" do
      expect(data[:tui_panel_name_value]).to eq("stack")
    end

    it "JSON-encodes an empty keybinds Hash into the panel data value" do
      expect(data[:tui_panel_keybinds_value]).to eq("{}")
    end
  end

  describe "rendered output (with sub-panel focusables stubbed)" do
    before do
      # Stub the per-sub-panel focusables aggregators so the template
      # render doesn't pull in the live SettingsHelper#stack_reindex_focusables
      # — that helper is exercised by its own spec.
      allow_any_instance_of(Pito::Stack::PostgresSubPanelComponent).to receive(:focusables).and_return([])
      allow_any_instance_of(Pito::Stack::MeilisearchSubPanelComponent).to receive(:focusables).and_return([])
      allow_any_instance_of(Pito::Stack::VoyageSubPanelComponent).to receive(:focusables).and_return([])
      allow_any_instance_of(Pito::Stack::AssetsSubPanelComponent).to receive(:focusables).and_return([])
    end

    subject(:rendered) { render_inline(component) }

    let(:root) { rendered.css("section.pito-panel").first }

    it "renders the canonical pito-panel section wrapper" do
      expect(root).to be_present
      expect(root["class"]).to include("pito-panel")
      expect(root["class"]).to include("pito-panel--stack")
    end

    it "renders the title from the canonical home-panel i18n namespace" do
      title_span = rendered.css(".pito-pane__title").first
      expect(title_span).to be_present
      expect(title_span.text.strip).to eq("stack")
    end

    it "wires the tui-panel-cable Stimulus controller on the root section" do
      expect(root["data-controller"]).to include("tui-panel-cable")
    end

    it "emits the canonical cable name + screen data values on the root section" do
      expect(root["data-tui-panel-cable-name-value"]).to eq("stack")
      expect(root["data-tui-panel-cable-screen-value"]).to eq("home")
    end

    it "registers the panel as a tui-cursor target on the root section" do
      expect(root["data-tui-cursor-target"]).to eq("panel")
    end
  end
end
