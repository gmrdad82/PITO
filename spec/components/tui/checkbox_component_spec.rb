# frozen_string_literal: true

require "rails_helper"

# Tui::CheckboxComponent — universal 3-state checkbox primitive.
#
# A2 (2026-05-25) — added `indeterminate:` kwarg for the `[-]` third state.
# Three render modes (link / form-input / inert span) × three states.
RSpec.describe Tui::CheckboxComponent, type: :component do
  # ─── default state (2-state, unchecked) ──────────────────────────────
  describe "default rendering (unchecked, non-indeterminate)" do
    it "renders the [ ] glyph" do
      render_inline(described_class.new)
      expect(page).to have_css(".tui-checkbox__box", text: "[ ]")
    end

    it "renders as an inert <span> when no href or name is given" do
      render_inline(described_class.new)
      expect(page).to have_css("span.tui-checkbox")
      expect(page).to have_no_css("a.tui-checkbox")
      expect(page).to have_no_css("label.tui-checkbox")
    end

    it "does NOT add the --checked modifier class when unchecked" do
      render_inline(described_class.new(checked: false))
      html = page.native.to_html
      expect(html).not_to include("tui-checkbox--checked")
    end

    it "does NOT add the --indeterminate modifier class by default" do
      render_inline(described_class.new)
      html = page.native.to_html
      expect(html).not_to include("tui-checkbox--indeterminate")
    end

    it "exposes indeterminate? as false by default" do
      component = described_class.new
      expect(component.indeterminate?).to be false
    end
  end

  # ─── checked state ────────────────────────────────────────────────────
  describe "checked: true" do
    it "renders the [x] glyph" do
      render_inline(described_class.new(checked: true))
      expect(page).to have_css(".tui-checkbox__box", text: "[x]")
    end

    it "adds the --checked modifier class" do
      render_inline(described_class.new(checked: true))
      expect(page).to have_css(".tui-checkbox--checked")
    end

    it "does NOT add --indeterminate when only checked: true is given" do
      render_inline(described_class.new(checked: true))
      html = page.native.to_html
      expect(html).not_to include("tui-checkbox--indeterminate")
    end
  end

  # ─── indeterminate state (A2) ─────────────────────────────────────────
  describe "indeterminate: true" do
    it "renders the [-] glyph regardless of checked: false (default)" do
      render_inline(described_class.new(indeterminate: true))
      expect(page).to have_css(".tui-checkbox__box", text: "[-]")
    end

    it "renders the [-] glyph even when checked: true is also passed" do
      render_inline(described_class.new(checked: true, indeterminate: true))
      expect(page).to have_css(".tui-checkbox__box", text: "[-]")
    end

    it "adds the --indeterminate modifier class" do
      render_inline(described_class.new(indeterminate: true))
      expect(page).to have_css(".tui-checkbox--indeterminate")
    end

    it "does NOT add the --checked modifier class when indeterminate + unchecked" do
      render_inline(described_class.new(indeterminate: true))
      html = page.native.to_html
      expect(html).not_to include("tui-checkbox--checked")
    end

    it "exposes indeterminate? as true" do
      component = described_class.new(indeterminate: true)
      expect(component.indeterminate?).to be true
    end

    it "glyph returns '-' when indeterminate" do
      component = described_class.new(indeterminate: true, checked: true)
      expect(component.glyph).to eq("-")
    end
  end

  # ─── link render mode ─────────────────────────────────────────────────
  describe "link render mode (href: given)" do
    it "renders as <a> element" do
      render_inline(described_class.new(href: "/toggle?foo=yes"))
      expect(page).to have_css("a.tui-checkbox")
    end

    it "renders --indeterminate class on the <a> when indeterminate: true" do
      render_inline(described_class.new(href: "/toggle", indeterminate: true))
      expect(page).to have_css("a.tui-checkbox--indeterminate")
    end

    it "renders the [-] glyph in link mode when indeterminate: true" do
      render_inline(described_class.new(href: "/toggle", indeterminate: true))
      expect(page).to have_css(".tui-checkbox__box", text: "[-]")
    end

    it "renders [-] glyph in link mode overriding checked: true" do
      render_inline(described_class.new(href: "/toggle", checked: true, indeterminate: true))
      expect(page).to have_css(".tui-checkbox__box", text: "[-]")
    end
  end

  # ─── form input render mode ───────────────────────────────────────────
  describe "form input render mode (name: given, no href)" do
    it "renders as <label> element" do
      render_inline(described_class.new(name: "my_flag"))
      expect(page).to have_css("label.tui-checkbox")
    end

    it "renders --indeterminate class on the <label> when indeterminate: true" do
      render_inline(described_class.new(name: "my_flag", indeterminate: true))
      expect(page).to have_css("label.tui-checkbox--indeterminate")
    end
  end

  # ─── label rendering ──────────────────────────────────────────────────
  describe "label kwarg" do
    it "renders label text after the box when provided" do
      render_inline(described_class.new(label: "sync"))
      expect(page).to have_css(".tui-checkbox__label", text: "sync")
    end

    it "omits the label span when label: is nil" do
      render_inline(described_class.new)
      expect(page).to have_no_css(".tui-checkbox__label")
    end

    it "renders label in indeterminate state" do
      render_inline(described_class.new(label: "paused", indeterminate: true))
      expect(page).to have_css(".tui-checkbox__label", text: "paused")
    end
  end

  # ─── glyph helper ─────────────────────────────────────────────────────
  describe "#glyph" do
    it "returns ' ' when unchecked and not indeterminate" do
      expect(described_class.new(checked: false).glyph).to eq(" ")
    end

    it "returns 'x' when checked and not indeterminate" do
      expect(described_class.new(checked: true).glyph).to eq("x")
    end

    it "returns '-' when indeterminate (regardless of checked)" do
      expect(described_class.new(indeterminate: true, checked: false).glyph).to eq("-")
      expect(described_class.new(indeterminate: true, checked: true).glyph).to eq("-")
    end
  end

  # ─── render mode detection helpers ───────────────────────────────────
  describe "render mode predicates" do
    it "renders_as_link? is true when href is given" do
      expect(described_class.new(href: "/x").renders_as_link?).to be true
    end

    it "renders_as_form_input? is true when name given without href" do
      expect(described_class.new(name: "flag").renders_as_form_input?).to be true
    end

    it "renders_as_form_input? is false when href is also given (link wins)" do
      expect(described_class.new(name: "flag", href: "/x").renders_as_form_input?).to be false
    end
  end
end
