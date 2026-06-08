# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pito::Chat::Handlers::Schedule do
  # All paths use the real lexer+parser so that token types (number, colon,
  # unknown "-") match what the handler's date-detection logic expects.
  def schedule_real(input)
    msg = Pito::Chat::Parser.call(
      Pito::Lex::Lexer.call(input), raw: input, conversation: Conversation.singleton
    )
    described_class.new(message: msg, conversation: Conversation.singleton).call
  end

  let!(:channel) { create(:channel) }
  let!(:video)   { create(:video, channel: channel, title: "Episode One", privacy_status: :public, publish_at: nil) }

  # ── Happy paths ───────────────────────────────────────────────────────────────

  it "sets privacy_status to private and publish_at when given YYYY-MM-DD HH:MM" do
    schedule_real("schedule video Episode One #{7.days.from_now.strftime('%Y-%m-%d %H:%M')}")
    video.reload
    expect(video.privacy_status).to eq("private")
    expect(video.publish_at).not_to be_nil
  end

  it "sets privacy_status to private and publish_at when given YYYY-MM-DD only" do
    schedule_real("schedule video Episode One #{7.days.from_now.strftime('%Y-%m-%d')}")
    video.reload
    expect(video.privacy_status).to eq("private")
    expect(video.publish_at).not_to be_nil
  end

  it "returns a system Ok result with the video title in the outcome copy" do
    result = schedule_real("schedule video Episode One #{7.days.from_now.strftime('%Y-%m-%d')}")
    expect(result).to be_a(Pito::Chat::Result::Ok)
    expect(result.events.first[:kind]).to eq(:system)
    expect(result.events.first[:payload]["text"]).to include("Episode One")
  end

  it "resolves by bare id" do
    result = schedule_real("schedule video #{video.id} #{7.days.from_now.strftime('%Y-%m-%d')}")
    expect(result).to be_a(Pito::Chat::Result::Ok)
    expect(video.reload.privacy_status).to eq("private")
  end

  it "resolves by #id" do
    result = schedule_real("schedule video ##{video.id} #{7.days.from_now.strftime('%Y-%m-%d')}")
    expect(result).to be_a(Pito::Chat::Result::Ok)
    expect(video.reload.privacy_status).to eq("private")
  end

  it "resolves with plural noun filler 'videos'" do
    result = schedule_real("schedule videos #{video.id} #{7.days.from_now.strftime('%Y-%m-%d')}")
    expect(result).to be_a(Pito::Chat::Result::Ok)
    expect(video.reload.privacy_status).to eq("private")
  end

  # ── Error paths ───────────────────────────────────────────────────────────────

  it "returns a usage hint when no reference is given" do
    # Just the verb with no body
    msg = Pito::Chat::Message.new(verb: :schedule, body_tokens: [], kind: :new_turn, raw: "schedule")
    result = described_class.new(message: msg, conversation: Conversation.singleton).call
    expect(result).to be_a(Pito::Chat::Result::Error)
    expect(result.message_key).to eq("pito.chat.schedule.needs_ref")
  end

  it "returns a bad_when error for an unparseable date string" do
    result = schedule_real("schedule video #{video.id} next-tuesday")
    expect(result).to be_a(Pito::Chat::Result::Error)
    expect(result.message_key).to eq("pito.chat.schedule.bad_when")
  end

  it "returns a bad_when error for a calendrically invalid date (month 99)" do
    result = schedule_real("schedule video #{video.id} 2025-99-01")
    expect(result).to be_a(Pito::Chat::Result::Error)
    expect(result.message_key).to eq("pito.chat.schedule.bad_when")
  end

  it "returns a witty in-past error for a past date" do
    result = schedule_real("schedule video Episode One 2020-01-01")
    expect(result).to be_a(Pito::Chat::Result::Ok)
    expect(result.events.first[:payload]["text"]).to include("Episode One")
  end

  it "returns a witty not-found for an unknown video reference" do
    result = schedule_real("schedule video nonexistent #{7.days.from_now.strftime('%Y-%m-%d')}")
    expect(result.events.first[:payload]["text"]).to include("nonexistent")
  end

  context "video title with apostrophe resolved via real lexer/parser" do
    let!(:apos_video) { create(:video, channel: channel, title: "Let's Play Bloodborne") }

    it "resolves the video when typed naturally with a date" do
      result = schedule_real("schedule video Let's Play Bloodborne #{7.days.from_now.strftime('%Y-%m-%d')}")
      expect(result).to be_a(Pito::Chat::Result::Ok)
      expect(apos_video.reload.privacy_status).to eq("private")
      expect(apos_video.reload.publish_at).not_to be_nil
    end

    it "resolves with a datetime HH:MM" do
      result = schedule_real("schedule video Let's Play Bloodborne #{7.days.from_now.strftime('%Y-%m-%d %H:%M')}")
      expect(result).to be_a(Pito::Chat::Result::Ok)
      expect(apos_video.reload.publish_at).not_to be_nil
    end
  end
end
