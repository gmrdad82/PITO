# Phase 1C (2026-05-22) — Tui::SizeGuardDialogComponent spec.
require "rails_helper"

RSpec.describe Tui::SizeGuardDialogComponent, type: :component do
  subject(:component) { described_class.new }

  describe "constants" do
    it "locks MIN_WIDTH_PX at 1200" do
      expect(described_class::MIN_WIDTH_PX).to eq(1200)
    end

    it "locks MIN_HEIGHT_PX at 800" do
      expect(described_class::MIN_HEIGHT_PX).to eq(800)
    end

    it "exposes the canonical DIALOG_ID" do
      expect(described_class::DIALOG_ID).to eq("size-guard-dialog")
    end
  end

  describe "rendering" do
    before { render_inline(component) }

    it "renders a <dialog> element" do
      expect(page).to have_css("dialog")
    end

    it "renders a <dialog> with id 'size-guard-dialog'" do
      expect(page).to have_css("dialog##{described_class::DIALOG_ID}")
    end

    it "applies the tui-size-guard-dialog class on the <dialog>" do
      expect(page).to have_css("dialog.tui-size-guard-dialog")
    end

    it "mounts the tui-size-guard Stimulus controller on the <dialog>" do
      expect(page.find("dialog")["data-controller"]).to include("tui-size-guard")
    end

    it "always mounts the canonical tui-dialog controller too" do
      expect(page.find("dialog")["data-controller"]).to include("tui-dialog")
    end

    it "renders the i18n title in the top-border-left" do
      expect(page).to have_css(
        ".tui-dialog-frame__title-left",
        text: I18n.t("tui.size_guard.title")
      )
    end

    it "renders the Esc-to-close hint in the top-border-right" do
      expect(page).to have_css(".tui-dialog-frame__title-right", text: "Esc to close")
    end

    it "renders the message paragraph with the interpolated minimums" do
      expect(page).to have_css(
        ".tui-size-guard-dialog__message",
        text: "resize the window to at least 1200×800 to continue."
      )
    end
  end

  describe "#title" do
    it "returns the i18n title key" do
      expect(component.title).to eq(I18n.t("tui.size_guard.title"))
    end
  end

  describe "#message" do
    it "interpolates MIN_WIDTH_PX and MIN_HEIGHT_PX into the i18n message" do
      expect(component.message).to include("1200")
      expect(component.message).to include("800")
    end
  end
end
