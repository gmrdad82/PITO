# frozen_string_literal: true

require "rails_helper"

# Tui::TstNoticeComponent — ephemeral centered notice slot for the TST.
#
# Phase 1D (2026-05-24 sync-rebuild) — verifies the SSR contract the
# JS controller relies on: a root span with `data-controller="tui-notice"`,
# a `data-tui-notice-duration-value` attr seeded from the kwarg, an
# inner `data-tui-notice-target="slot"` host, and an empty slot on
# first paint (events drive the text).
RSpec.describe Tui::TstNoticeComponent, type: :component do
  describe "default render" do
    subject(:render!) { render_inline(described_class.new) }

    it "renders without raising" do
      expect { render! }.not_to raise_error
    end

    it "renders the .tui-tst-notice root span" do
      render!
      expect(page).to have_css("span.tui-tst-notice")
    end

    it "wires the tui-notice Stimulus controller on the root" do
      render!
      expect(page).to have_css('.tui-tst-notice[data-controller="tui-notice"]')
    end

    it "seeds the default duration value (2500ms)" do
      render!
      expect(page).to have_css('.tui-tst-notice[data-tui-notice-duration-value="2500"]')
    end

    it "starts with severity=none so the CSS data-severity hook is set" do
      render!
      expect(page).to have_css('.tui-tst-notice[data-severity="none"]')
    end

    it "renders the slot target host inside the root" do
      render!
      expect(page).to have_css('.tui-tst-notice .tui-tst-notice__slot[data-tui-notice-target="slot"]')
    end

    it "renders the slot empty on first paint (events drive text)" do
      render!
      slot = page.find('.tui-tst-notice__slot')
      expect(slot.text.strip).to eq("")
    end
  end

  describe "custom duration_ms" do
    it "uses the provided integer duration" do
      render_inline(described_class.new(duration_ms: 4000))
      expect(page).to have_css('.tui-tst-notice[data-tui-notice-duration-value="4000"]')
    end

    it "coerces a string-shaped duration to an integer" do
      render_inline(described_class.new(duration_ms: "1200"))
      expect(page).to have_css('.tui-tst-notice[data-tui-notice-duration-value="1200"]')
    end

    it "falls back to the default for non-positive durations" do
      render_inline(described_class.new(duration_ms: 0))
      expect(page).to have_css('.tui-tst-notice[data-tui-notice-duration-value="2500"]')
    end

    it "falls back to the default for negative durations" do
      render_inline(described_class.new(duration_ms: -10))
      expect(page).to have_css('.tui-tst-notice[data-tui-notice-duration-value="2500"]')
    end
  end

  describe "constants" do
    it "exposes DEFAULT_DURATION_MS" do
      expect(described_class::DEFAULT_DURATION_MS).to eq(2500)
    end
  end

  describe "Stimulus controller contract (static JS source check)" do
    let(:js_source) do
      Rails.root.join("app/javascript/controllers/tui_notice_controller.js").read
    end

    it "registers a `slot` target matching the VC template" do
      expect(js_source).to match(/static targets = \[\s*"slot"\s*\]/)
    end

    it "declares a `duration` Number value with the same 2500ms default as the Ruby VC" do
      expect(js_source).to match(/duration:\s*\{ type: Number, default: 2500 \}/)
    end

    it "listens for `tui:notice` document events in connect()" do
      expect(js_source).to include('document.addEventListener("tui:notice"')
    end

    it "removes the `tui:notice` listener in disconnect()" do
      expect(js_source).to include('document.removeEventListener("tui:notice"')
    end

    it "writes the message into slotTarget.textContent" do
      expect(js_source).to match(/this\.slotTarget\.textContent\s*=\s*message/)
    end

    it "adds the `is-visible` class on event + clears it on timer" do
      expect(js_source).to include('this.element.classList.add("is-visible")')
      expect(js_source).to include('this.element.classList.remove("is-visible")')
    end
  end
end
