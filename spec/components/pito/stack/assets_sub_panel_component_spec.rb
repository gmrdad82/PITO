require "rails_helper"

RSpec.describe Pito::Stack::AssetsSubPanelComponent, type: :component do
  let(:writable_status)   { { present: true, writable: true, path: "/assets", size_bytes: 1024, file_count: 10 } }
  let(:read_only_status)  { { present: true, writable: false, path: "/assets", size_bytes: 1024, file_count: 10 } }
  let(:absent_status)     { { present: false, writable: false, path: nil, size_bytes: 0, file_count: 0 } }

  describe "hint line — writable" do
    before do
      render_inline(described_class.new(storage_status: writable_status, breakdown: []))
    end

    it "renders a single hint paragraph (not two spans)" do
      expect(page).to have_css("p.pito-sub-panel__hint", count: 1)
      expect(page).not_to have_css(".pito-sub-panel__hint-label")
      expect(page).not_to have_css(".pito-sub-panel__hint-status")
    end

    it "renders the full i18n hint text when writable" do
      expected = I18n.t("tui.stack.hint.assets",
        status: I18n.t("tui.stack.status.writable"))
      expect(page).to have_css("p.pito-sub-panel__hint", text: expected)
    end

    it "applies is-success class when writable" do
      expect(page).to have_css("p.pito-sub-panel__hint.is-success")
    end

    it "does not render a Tui::ChipComponent in the title actions" do
      expect(page).not_to have_css(".tui-chip")
    end
  end

  describe "hint line — read-only (present but not writable)" do
    before do
      render_inline(described_class.new(storage_status: read_only_status, breakdown: []))
    end

    it "renders the full i18n hint text when not writable" do
      expected = I18n.t("tui.stack.hint.assets",
        status: I18n.t("tui.stack.status.not_writable"))
      expect(page).to have_css("p.pito-sub-panel__hint", text: expected)
    end

    it "applies is-danger class when read-only" do
      expect(page).to have_css("p.pito-sub-panel__hint.is-danger")
    end
  end

  describe "hint line — absent (directory missing)" do
    before do
      render_inline(described_class.new(storage_status: absent_status, breakdown: []))
    end

    it "renders the full i18n hint text when absent" do
      expected = I18n.t("tui.stack.hint.assets",
        status: I18n.t("tui.stack.status.not_writable"))
      expect(page).to have_css("p.pito-sub-panel__hint", text: expected)
    end

    it "applies is-danger class when absent" do
      expect(page).to have_css("p.pito-sub-panel__hint.is-danger")
    end
  end

  describe "#hint_text" do
    it "returns i18n'd hint with writable status" do
      component = described_class.new(storage_status: writable_status, breakdown: [])
      expected = I18n.t("tui.stack.hint.assets",
        status: I18n.t("tui.stack.status.writable"))
      expect(component.hint_text).to eq(expected)
    end

    it "returns i18n'd hint with not_writable status when read-only" do
      component = described_class.new(storage_status: read_only_status, breakdown: [])
      expected = I18n.t("tui.stack.hint.assets",
        status: I18n.t("tui.stack.status.not_writable"))
      expect(component.hint_text).to eq(expected)
    end

    it "returns i18n'd hint with not_writable status when absent" do
      component = described_class.new(storage_status: absent_status, breakdown: [])
      expected = I18n.t("tui.stack.hint.assets",
        status: I18n.t("tui.stack.status.not_writable"))
      expect(component.hint_text).to eq(expected)
    end
  end

  describe "#hint_color_class" do
    it "returns 'is-success' when writable" do
      component = described_class.new(storage_status: writable_status, breakdown: [])
      expect(component.hint_color_class).to eq("is-success")
    end

    it "returns 'is-danger' when read-only" do
      component = described_class.new(storage_status: read_only_status, breakdown: [])
      expect(component.hint_color_class).to eq("is-danger")
    end

    it "returns 'is-danger' when absent" do
      component = described_class.new(storage_status: absent_status, breakdown: [])
      expect(component.hint_color_class).to eq("is-danger")
    end
  end

  describe "hint line renders before breakdown table" do
    let(:breakdown) do
      [ { label: "Cover arts", file_count: 5, size_bytes: 512 } ]
    end

    before do
      render_inline(described_class.new(storage_status: writable_status, breakdown: breakdown))
    end

    it "renders the hint paragraph" do
      expect(page).to have_css("p.pito-sub-panel__hint")
    end

    it "renders the breakdown table" do
      expect(page).to have_css("table.tui-table")
    end
  end
end
