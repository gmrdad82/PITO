require "rails_helper"

RSpec.describe Pito::LatestVideosPanelComponent, type: :component do
  subject(:rendered) { render_inline(described_class.new) }

  let(:root) { rendered.css("section.pito-panel").first }

  it "renders the canonical pito-panel section wrapper" do
    expect(root).to be_present
    expect(root["class"]).to include("pito-panel")
    expect(root["class"]).to include("pito-panel--latest-videos")
  end

  it "renders the rescued pito-pane chrome with the i18n title" do
    title = I18n.t("tui.home.panels.latest_videos.title")
    expect(title).to eq("latest videos")
    expect(root["class"]).to include("pane")
    expect(root["class"]).to include("pito-pane")
    header = rendered.css(".pito-pane__title").first
    expect(header).to be_present
    expect(header.text.strip).to eq(title)
  end

  it "wires the tui-panel-cable Stimulus controller" do
    expect(root["data-controller"]).to include("tui-panel-cable")
  end

  it "emits the canonical cable name + screen data values" do
    expect(root["data-tui-panel-cable-name-value"]).to eq("latest_videos")
    expect(root["data-tui-panel-cable-screen-value"]).to eq("home")
  end

  it "registers the panel as a tui-cursor target" do
    expect(root["data-tui-cursor-target"]).to eq("panel")
  end

  it "emits latest_videos_sync as the leading focusable + empty keybinds in the blank-shell round" do
    expect(root["data-tui-panel-focusables-value"]).to eq("latest_videos_sync")
    expect(root["data-tui-panel-keybinds-value"]).to eq("{}")
  end

  it "renders the placeholder body inside the panel fieldset" do
    placeholder = rendered.css(".tui-panel-fieldset .pito-panel__placeholder").first
    expect(placeholder).to be_present
    expect(placeholder.text.strip).to eq("[ panel content TBD ]")
  end

  describe "panel-level [ ] sync action (2026-05-24)" do
    it "renders the Tui::SyncIndicatorComponent with target=home.latest_videos" do
      sync = rendered.css("button.tui-sync-word--target").first
      expect(sync).to be_present
      expect(sync["data-tui-sync-indicator-target-value"]).to eq("home.latest_videos")
    end

    it "carries data-tui-focusable-key=latest_videos_sync" do
      sync = rendered.css("button.tui-sync-word--target").first
      expect(sync["data-tui-focusable-key"]).to eq("latest_videos_sync")
    end
  end

  describe "PANEL_NAME" do
    it "matches the canonical Pito::PanelChannel allowlist entry" do
      expect(described_class::PANEL_NAME).to eq(:latest_videos)
      expect(Pito::PanelChannel::ALLOWED_PANELS).to include(described_class::PANEL_NAME.to_s)
    end
  end
end
