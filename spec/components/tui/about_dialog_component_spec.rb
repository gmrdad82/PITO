# D9 (2026-05-22) — Tui::AboutDialogComponent spec.
require "rails_helper"

RSpec.describe Tui::AboutDialogComponent, type: :component do
  subject(:component) { described_class.new }

  describe "dialog chrome" do
    it "renders a <dialog> element" do
      render_inline(component)
      expect(page).to have_css("dialog")
    end

    it "uses DIALOG_ID as the element id" do
      render_inline(component)
      expect(page).to have_css("dialog##{described_class::DIALOG_ID}")
    end

    it "renders the i18n title 'about' in the top-border-left" do
      render_inline(component)
      expect(page).to have_css(".tui-dialog-frame__title-left", text: "about")
    end

    it "renders the esc_to_close hint in the top-border-right" do
      render_inline(component)
      expect(page).to have_css(".tui-dialog-frame__title-right", text: "Esc to close")
    end

    it "applies the tui-about-dialog class" do
      render_inline(component)
      expect(page).to have_css("dialog.tui-about-dialog")
    end
  end

  describe "identity block" do
    it "renders the app name from i18n" do
      render_inline(component)
      expect(rendered_content).to include("pito")
    end

    it "renders the subtitle from i18n" do
      render_inline(component)
      expect(rendered_content).to include("best YouTube tool")
    end
  end

  describe "KV rows" do
    it "renders a .tui-about-dialog__kv element" do
      render_inline(component)
      expect(page).to have_css(".tui-about-dialog__kv")
    end

    it "renders the version label from i18n" do
      render_inline(component)
      expect(page).to have_css("dt.text-muted", text: "version")
    end

    it "renders the license label from i18n" do
      render_inline(component)
      expect(page).to have_css("dt.text-muted", text: "license")
    end

    it "renders the source label from i18n" do
      render_inline(component)
      expect(page).to have_css("dt.text-muted", text: "source")
    end

    it "renders the commit label from i18n" do
      render_inline(component)
      expect(page).to have_css("dt.text-muted", text: "commit")
    end

    it "renders the contact label from i18n" do
      render_inline(component)
      expect(page).to have_css("dt.text-muted", text: "contact")
    end

    it "renders the env label from i18n" do
      render_inline(component)
      expect(page).to have_css("dt.text-muted", text: "env")
    end

    it "renders the license value AGPL-3.0 in a bracketed link" do
      render_inline(component)
      expect(rendered_content).to include("AGPL-3.0")
    end

    it "renders the contact value" do
      render_inline(component)
      expect(rendered_content).to include("gmrdad82 [at] gmail [dot] com")
    end
  end

  describe "logo image" do
    it "renders an img element for the logo" do
      render_inline(component)
      expect(page).to have_css("img.tui-about-dialog__logo")
    end
  end

  describe "constants" do
    it "DIALOG_ID is about-dialog" do
      expect(described_class::DIALOG_ID).to eq("about-dialog")
    end

    it "REPO_SLUG points to gmrdad82/pito" do
      expect(described_class::REPO_SLUG).to eq("gmrdad82/pito")
    end
  end

  describe "#version_string" do
    it "returns a string prefixed with v" do
      expect(component.version_string).to start_with("v")
    end
  end

  describe "#version_url" do
    it "includes the GitHub releases URL for the repo" do
      expect(component.version_url).to include("github.com/gmrdad82/pito/releases/tag/")
    end
  end

  describe "#license_url" do
    it "points to the LICENSE file on GitHub" do
      expect(component.license_url).to include("github.com/gmrdad82/pito/blob/main/LICENSE")
    end
  end

  describe "#source_url" do
    it "points to the GitHub repo root" do
      expect(component.source_url).to eq("https://github.com/gmrdad82/pito")
    end
  end

  describe "#env" do
    it "returns the current Rails environment" do
      expect(component.env).to eq(Rails.env)
    end
  end

  # FB-ITEM-3 (2026-05-22) — wiring + i18n regression coverage.
  describe "Stimulus wiring (SPACE+a + :about open path)" do
    it "mounts the tui-about-dialog controller on the dialog root" do
      render_inline(component)
      expect(page).to have_css("dialog[data-controller~='tui-about-dialog']")
    end
  end

  describe "i18n compliance (no hardcoded English)" do
    around do |example|
      example.run
    ensure
      I18n.backend.reload!
      I18n.backend.send(:init_translations) if I18n.backend.respond_to?(:init_translations, true)
    end

    it "sources the license value from tui.about.license_value (not hardcoded)" do
      I18n.backend.store_translations(:en, tui: { about: { license_value: "CUSTOM_LICENSE_PROBE" } })
      render_inline(component)
      expect(rendered_content).to include("CUSTOM_LICENSE_PROBE")
    end

    it "sources the contact value from tui.about.contact_value (not hardcoded)" do
      I18n.backend.store_translations(:en, tui: { about: { contact_value: "CUSTOM_CONTACT_PROBE" } })
      render_inline(component)
      expect(rendered_content).to include("CUSTOM_CONTACT_PROBE")
    end

    it "sources the version prefix from tui.about.version_prefix (not hardcoded 'v')" do
      I18n.backend.store_translations(:en, tui: { about: { version_prefix: "PROBE_" } })
      expect(component.version_string).to start_with("PROBE_")
    end

    it "template source contains no bare hardcoded license string" do
      template = Rails.root.join("app/components/tui/about_dialog_component.html.erb").read
      expect(template).not_to include("\"AGPL-3.0\"")
      expect(template).not_to include("'AGPL-3.0'")
    end

    it "template source contains no bare hardcoded contact string" do
      template = Rails.root.join("app/components/tui/about_dialog_component.html.erb").read
      expect(template).not_to include("\"gmrdad82 [at] gmail [dot] com\"")
      expect(template).not_to include("'gmrdad82 [at] gmail [dot] com'")
    end
  end
end
