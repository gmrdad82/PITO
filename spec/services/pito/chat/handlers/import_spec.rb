# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pito::Chat::Handlers::Import do
  def handler_for(raw = "import")
    described_class.new(
      message: Pito::Chat::Message.new(
        verb: :import,
        body_tokens: [],
        kind: :new_turn,
        raw: raw
      ),
      conversation: Conversation.singleton
    )
  end

  it "returns a Result::Error with the usage_hint key" do
    result = handler_for.call
    expect(result).to be_a(Pito::Chat::Result::Error)
    expect(result.message_key).to eq("pito.chat.import.usage_hint")
  end

  it "returns the usage_hint for any bare import input" do
    result = handler_for("import something random").call
    expect(result).to be_a(Pito::Chat::Result::Error)
    expect(result.message_key).to eq("pito.chat.import.usage_hint")
  end
end
