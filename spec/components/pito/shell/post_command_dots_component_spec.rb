# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pito::Shell::PostCommandDotsComponent do
  describe "rendered output" do
    it "renders the comet container div" do
      node = render_inline(described_class.new)
      expect(node.css("div.pito-comet")).not_to be_empty
    end

    it "renders exactly 8 dot elements" do
      node = render_inline(described_class.new)
      expect(node.css("div.pito-comet div.dot").length).to eq(8)
    end

    it "uses the pito-comet container class" do
      node = render_inline(described_class.new)
      expect(node.css("div.pito-comet")).not_to be_empty
    end

    it "renders 8 dot elements inside the comet" do
      node = render_inline(described_class.new)
      expect(node.css("div.pito-comet div.dot").length).to eq(8)
    end
  end
end
