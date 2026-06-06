# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pito::FollowUp::AffordanceComponent do
  describe "normal (non-consumed)" do
    let(:node) do
      render_inline(described_class.new(
        handle:   "delta-4823",
        usage:    "preview <name> · apply <name>",
        consumed: false
      ))
    end

    it "renders the handle with a # prefix" do
      expect(node.text).to include("#delta-4823")
    end

    it "renders the usage string" do
      expect(node.text).to include("preview <name> · apply <name>")
    end
  end

  describe "consumed" do
    it "renders nothing when consumed is true" do
      node = render_inline(described_class.new(
        handle:   "delta-4823",
        usage:    "preview <name> · apply <name>",
        consumed: true
      ))
      expect(node.to_html.strip).to be_empty
    end

    it "renders nothing when consumed is the string 'true' (from DB)" do
      node = render_inline(described_class.new(
        handle:   "delta-4823",
        usage:    "some usage",
        consumed: "true"
      ))
      expect(node.to_html.strip).to be_empty
    end
  end

  describe "missing handle" do
    it "renders nothing when handle is blank" do
      node = render_inline(described_class.new(
        handle:   "",
        usage:    "preview <name>",
        consumed: false
      ))
      expect(node.to_html.strip).to be_empty
    end
  end
end
