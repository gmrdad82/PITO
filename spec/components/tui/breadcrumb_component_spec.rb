# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tui::BreadcrumbComponent, type: :component do
  describe "idle (screen only, no panel)" do
    subject(:component) { described_class.new(screen: "home") }

    it "renders without raising" do
      expect { render_inline(component) }.not_to raise_error
    end

    it "renders the screen label as the idle fallback in the sb-section span" do
      render_inline(component)
      expect(page).to have_css("span.sb-section", text: "home")
    end

    it "does not render the legacy 4-span structure (dropped in Phase 2D)" do
      render_inline(component)
      expect(page).not_to have_css(".sb-section__panel")
      expect(page).not_to have_css(".sb-section__sub-panel")
      expect(page).not_to have_css(".sb-section__sub-panel-paren")
    end

    it "carries data-tui-status-bar-target=section" do
      render_inline(component)
      expect(page).to have_css("[data-tui-status-bar-target='section']")
    end

    it "carries both tui-breadcrumb and tui-transition controllers" do
      render_inline(component)
      controller_attr = page.find("span.sb-section")["data-controller"]
      expect(controller_attr).to include("tui-breadcrumb")
      expect(controller_attr).to include("tui-transition")
    end

    it "sets data-tui-transition-value-value to the screen name" do
      render_inline(component)
      expect(page).to have_css('[data-tui-transition-value-value="home"]')
    end

    it "sets data-tui-transition-color-value to accent-pale (no panel focused)" do
      render_inline(component)
      expect(page).to have_css('[data-tui-transition-color-value="accent-pale"]')
    end

    it "emits NO segments descriptor in idle state" do
      render_inline(component)
      expect(page).not_to have_css("[data-tui-transition-segments-value]")
    end

    it "exposes data-tui-breadcrumb-screen-value" do
      render_inline(component)
      expect(page).to have_css('[data-tui-breadcrumb-screen-value="home"]')
    end

    it "wires the tui-transition outlet to .sb-section" do
      render_inline(component)
      expect(page).to have_css('[data-tui-breadcrumb-tui-transition-outlet=".sb-section"]')
    end
  end

  describe "panel only (no sub-panel)" do
    subject(:component) { described_class.new(screen: "home", panel: "security") }

    it "renders ONLY the panel name (screen prefix dropped in Phase 2E)" do
      render_inline(component)
      expect(page).to have_css("span.sb-section", text: "security")
      expect(page).not_to have_css("span.sb-section", text: "home security")
    end

    it "sets data-tui-transition-value-value to the panel name" do
      render_inline(component)
      expect(page).to have_css('[data-tui-transition-value-value="security"]')
    end

    it "sets data-tui-transition-color-value to accent (panel focused)" do
      render_inline(component)
      expect(page).to have_css('[data-tui-transition-color-value="accent"]')
    end

    it "emits NO segments descriptor in panel-only state" do
      render_inline(component)
      expect(page).not_to have_css("[data-tui-transition-segments-value]")
    end
  end

  describe "panel + sub_panel" do
    subject(:component) { described_class.new(screen: "home", panel: "security", sub_panel: "totp") }

    it "renders 'panel:(sub_panel)' (screen prefix dropped in Phase 2E)" do
      render_inline(component)
      expect(page).to have_css("span.sb-section", text: "security:(totp)")
    end

    it "sets data-tui-transition-value-value to the formatted string" do
      render_inline(component)
      expect(page).to have_css('[data-tui-transition-value-value="security:(totp)"]')
    end

    it "sets host color to accent-pale so the un-segmented delimiters inherit accent-pale" do
      render_inline(component)
      expect(page).to have_css('[data-tui-transition-color-value="accent-pale"]')
    end

    it "emits a segments descriptor with two ranges (panel + sub-panel)" do
      render_inline(component)
      segments_attr = page.find("span.sb-section")["data-tui-transition-segments-value"]
      expect(segments_attr).to be_present
      parsed = JSON.parse(segments_attr)
      expect(parsed.length).to eq(2)
      expect(parsed[0]).to eq("name" => "panel_title", "range" => [ 0, 8 ], "color" => "accent-pale")
      expect(parsed[1]).to eq("name" => "sub_panel_title", "range" => [ 10, 14 ], "color" => "accent")
    end

    it "computes the sub-panel range using +2 offset for the ':(' delimiter" do
      # "security:(totp)" → s=0..7 (8 chars), then ":(" at 8..9 → sub starts at 10, ends at 14 (totp = 4 chars)
      render_inline(component)
      segments_attr = page.find("span.sb-section")["data-tui-transition-segments-value"]
      parsed = JSON.parse(segments_attr)
      sub_segment = parsed.find { |s| s["name"] == "sub_panel_title" }
      expect(sub_segment["range"]).to eq([ 10, 14 ])
    end
  end

  describe ".format" do
    it "returns empty when panel is nil" do
      expect(described_class.format(nil, nil)).to eq("")
    end

    it "returns the panel string when sub_panel is nil" do
      expect(described_class.format("security", nil)).to eq("security")
    end

    it "returns 'panel:(sub_panel)' when both are present" do
      expect(described_class.format("security", "totp")).to eq("security:(totp)")
    end

    it "treats blank strings as absent" do
      expect(described_class.format("", "")).to eq("")
      expect(described_class.format("security", "")).to eq("security")
    end
  end

  describe "#current_value" do
    it "returns the screen name as the idle fallback when no panel is focused" do
      component = described_class.new(screen: "games")
      expect(component.current_value).to eq("games")
    end

    it "returns just the panel when panel is focused but no sub-panel" do
      component = described_class.new(screen: "games", panel: "list")
      expect(component.current_value).to eq("list")
    end

    it "returns 'panel:(sub_panel)' when both are focused" do
      component = described_class.new(screen: "games", panel: "list", sub_panel: "detail")
      expect(component.current_value).to eq("list:(detail)")
    end
  end

  describe "#segments_json" do
    it "returns an empty string in idle state" do
      component = described_class.new(screen: "home")
      expect(component.segments_json).to eq("")
    end

    it "returns an empty string in panel-only state" do
      component = described_class.new(screen: "home", panel: "security")
      expect(component.segments_json).to eq("")
    end

    it "returns the segments JSON for panel + sub-panel" do
      component = described_class.new(screen: "home", panel: "security", sub_panel: "totp")
      parsed = JSON.parse(component.segments_json)
      expect(parsed).to eq(
        [
          { "name" => "panel_title",     "range" => [ 0, 8 ],   "color" => "accent-pale" },
          { "name" => "sub_panel_title", "range" => [ 10, 14 ], "color" => "accent" }
        ]
      )
    end
  end

  describe "#color_for_state" do
    it "is :\"accent-pale\" in idle state" do
      expect(described_class.new(screen: "home").color_for_state).to eq(:"accent-pale")
    end

    it "is :accent in panel-only state" do
      expect(described_class.new(screen: "home", panel: "security").color_for_state).to eq(:accent)
    end

    it "is :\"accent-pale\" in panel + sub-panel state (segments override the sub-panel range to accent)" do
      expect(
        described_class.new(screen: "home", panel: "security", sub_panel: "totp").color_for_state
      ).to eq(:"accent-pale")
    end
  end
end
