# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pito::Chat::Handlers::Unlist do
  def tokens(*words)
    words.each_with_index.map do |w, i|
      Pito::Lex::Token.new(type: :word, value: w, position: i, preceded_by_space: i.positive?)
    end
  end

  def handler_for(*words)
    described_class.new(
      message: Pito::Chat::Message.new(verb: :unlist, body_tokens: tokens(*words), kind: :new_turn, raw: "unlist #{words.join(' ')}"),
      conversation: Conversation.singleton
    )
  end

  let!(:channel) { create(:channel) }
  let!(:video)   { create(:video, channel: channel, title: "Boss Fight Compilation", privacy_status: :public) }

  it "sets privacy_status to unlisted" do
    handler_for("video", "boss", "fight", "compilation").call
    expect(video.reload.privacy_status).to eq("unlisted")
  end

  it "returns a system Ok result with the video title in the outcome copy" do
    result = handler_for("video", "boss", "fight", "compilation").call
    expect(result).to be_a(Pito::Chat::Result::Ok)
    expect(result.events.first[:kind]).to eq(:system)
    expect(result.events.first[:payload]["text"]).to include("Boss Fight Compilation")
  end

  it "resolves by bare id" do
    result = handler_for("video", video.id.to_s).call
    expect(result).to be_a(Pito::Chat::Result::Ok)
    expect(video.reload.privacy_status).to eq("unlisted")
  end

  it "resolves by #id" do
    result = handler_for("video", "##{video.id}").call
    expect(result).to be_a(Pito::Chat::Result::Ok)
    expect(video.reload.privacy_status).to eq("unlisted")
  end

  it "resolves with plural noun filler 'videos'" do
    result = handler_for("videos", "boss", "fight", "compilation").call
    expect(result).to be_a(Pito::Chat::Result::Ok)
    expect(video.reload.privacy_status).to eq("unlisted")
  end

  it "returns a witty not-found for an unknown reference" do
    result = handler_for("video", "nonexistent").call
    expect(result.events.first[:payload]["text"]).to include("nonexistent")
  end

  it "returns a usage hint when no reference is given" do
    result = handler_for.call
    expect(result).to be_a(Pito::Chat::Result::Error)
    expect(result.message_key).to eq("pito.chat.unlist.needs_ref")
  end

  context "video title with apostrophe resolved via real lexer/parser" do
    let!(:apos_video) { create(:video, channel: channel, title: "Let's Play Sekiro", privacy_status: :public) }

    it "resolves the video when typed naturally" do
      result = Pito::Chat::Parser.call(
        Pito::Lex::Lexer.call("unlist video Let's Play Sekiro"),
        raw: "unlist video Let's Play Sekiro",
        conversation: Conversation.singleton
      )
      handler = described_class.new(message: result, conversation: Conversation.singleton)
      out = handler.call
      expect(out).to be_a(Pito::Chat::Result::Ok)
      expect(apos_video.reload.privacy_status).to eq("unlisted")
    end
  end
end
