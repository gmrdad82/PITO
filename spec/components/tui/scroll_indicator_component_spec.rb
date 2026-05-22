require "rails_helper"

RSpec.describe Tui::ScrollIndicatorComponent, type: :component do
  subject(:rendered) { render_inline(described_class.new) }

  it "renders both top and bottom span elements" do
    expect(rendered.css("span").length).to eq(2)
  end

  it "renders the top indicator with correct classes and glyph" do
    top = rendered.css("span.tui-scroll-indicator--top").first
    expect(top).to be_present
    expect(top["class"]).to include("tui-scroll-indicator")
    expect(top["class"]).to include("tui-scroll-indicator--top")
    expect(top.text.strip).to eq("▲")
  end

  it "renders the bottom indicator with correct classes and glyph" do
    bottom = rendered.css("span.tui-scroll-indicator--bottom").first
    expect(bottom).to be_present
    expect(bottom["class"]).to include("tui-scroll-indicator")
    expect(bottom["class"]).to include("tui-scroll-indicator--bottom")
    expect(bottom.text.strip).to eq("▼")
  end

  it "marks both spans aria-hidden" do
    rendered.css("span").each do |span|
      expect(span["aria-hidden"]).to eq("true")
    end
  end

  it "wires Stimulus target attributes for top and bottom" do
    top = rendered.css("span.tui-scroll-indicator--top").first
    bottom = rendered.css("span.tui-scroll-indicator--bottom").first
    expect(top["data-tui-scroll-indicator-target"]).to eq("top")
    expect(bottom["data-tui-scroll-indicator-target"]).to eq("bottom")
  end

  it "does not include the --visible modifier on initial render" do
    rendered.css("span").each do |span|
      expect(span["class"]).not_to include("tui-scroll-indicator--visible")
    end
  end
end
