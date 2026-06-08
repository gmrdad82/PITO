# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pito::Chat::Handlers::Publish do
  def tokens(*words)
    words.each_with_index.map do |w, i|
      Pito::Lex::Token.new(type: :word, value: w, position: i, preceded_by_space: i.positive?)
    end
  end

  def handler_for(*words)
    described_class.new(
      message: Pito::Chat::Message.new(verb: :publish, body_tokens: tokens(*words), kind: :new_turn, raw: "publish #{words.join(' ')}"),
      conversation: Conversation.singleton
    )
  end

  let!(:channel) { create(:channel) }
  let!(:video)   { create(:video, channel: channel, title: "My Review", privacy_status: :private, publish_at: 1.day.from_now) }

  it "sets privacy_status to public" do
    handler_for("video", "my", "review").call
    expect(video.reload.privacy_status).to eq("public")
  end

  it "clears publish_at" do
    handler_for("video", "my", "review").call
    expect(video.reload.publish_at).to be_nil
  end

  it "returns a system Ok result with the video title in the outcome copy" do
    result = handler_for("video", "my", "review").call
    expect(result).to be_a(Pito::Chat::Result::Ok)
    expect(result.events.first[:kind]).to eq(:system)
    expect(result.events.first[:payload]["text"]).to include("My Review")
  end

  it "resolves by bare id" do
    result = handler_for("video", video.id.to_s).call
    expect(result).to be_a(Pito::Chat::Result::Ok)
    expect(video.reload.privacy_status).to eq("public")
  end

  it "resolves by #id" do
    result = handler_for("video", "##{video.id}").call
    expect(result).to be_a(Pito::Chat::Result::Ok)
    expect(video.reload.privacy_status).to eq("public")
  end

  it "resolves with plural noun filler 'videos'" do
    result = handler_for("videos", "my", "review").call
    expect(result).to be_a(Pito::Chat::Result::Ok)
    expect(video.reload.privacy_status).to eq("public")
  end

  it "returns a witty not-found for an unknown reference" do
    result = handler_for("video", "nonexistent").call
    expect(result.events.first[:payload]["text"]).to include("nonexistent")
  end

  it "returns a usage hint when no reference is given" do
    result = handler_for.call
    expect(result).to be_a(Pito::Chat::Result::Error)
    expect(result.message_key).to eq("pito.chat.publish.needs_ref")
  end

  context "video title with apostrophe resolved via real lexer/parser" do
    let!(:apos_video) { create(:video, channel: channel, title: "Let's Play Elden Ring", privacy_status: :private) }

    it "resolves the video when typed naturally" do
      result = Pito::Chat::Parser.call(
        Pito::Lex::Lexer.call("publish video Let's Play Elden Ring"),
        raw: "publish video Let's Play Elden Ring",
        conversation: Conversation.singleton
      )
      handler = described_class.new(message: result, conversation: Conversation.singleton)
      out = handler.call
      expect(out).to be_a(Pito::Chat::Result::Ok)
      expect(apos_video.reload.privacy_status).to eq("public")
    end
  end
end
