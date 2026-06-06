# frozen_string_literal: true

require "rails_helper"
require "action_cable/test_helper"

# Fake mutate handler for controller tests.
# Defined at top-level so the constant is stable across examples.
unless defined?(ControllerSpecFakeMutate)
  class ControllerSpecFakeMutate < Pito::FollowUp::Handler
    target "ctrl_fake_mutate"
    mode   :mutate

    def call(event:, rest:, conversation:)
      Pito::FollowUp::Result::Mutation.new(kind: :enhanced, payload: { text: rest })
    end
  end
end

unless defined?(ControllerSpecFakeAppend)
  class ControllerSpecFakeAppend < Pito::FollowUp::Handler
    target "ctrl_fake_append"
    mode   :append

    def call(event:, rest:, conversation:)
      Pito::FollowUp::Result::Append.new(events: [ { kind: :system, payload: { text: rest } } ])
    end
  end
end

RSpec.describe "Follow-up engine — controller routing", type: :request do
  include ActionCable::TestHelper

  let(:conversation) { Conversation.singleton }

  before do
    seed = ROTP::Base32.random_base32
    AppSetting.enroll_totp!(seed:)
    post "/chat", params: { input: "/login #{ROTP::TOTP.new(seed).now}" }
    conversation.turns.destroy_all

    # Ensure the fake handlers are registered (TracePoint may have done this
    # already; register is idempotent for the same class).
    Pito::FollowUp::Registry.register(ControllerSpecFakeMutate)
    Pito::FollowUp::Registry.register(ControllerSpecFakeAppend)
  end

  # ── Mutate path ────────────────────────────────────────────────────────────

  context "mutate-mode follow-up (no echo, no turn)" do
    let(:source_turn) do
      conversation.turns.create!(input_kind: :slash, input_text: "/list", position: 99)
    end
    let!(:source_event) do
      Event.create_with_position!(
        conversation:, turn: source_turn, kind: "system",
        payload: {
          "reply_handle" => "zeta-1234",
          "reply_target" => "ctrl_fake_mutate",
          "text"         => "Choose wisely"
        }
      )
    end

    it "returns 204 No Content" do
      post "/chat", params: { input: "#zeta-1234 do-it", uuid: conversation.uuid }
      expect(response).to have_http_status(:no_content)
    end

    it "does NOT create a new Turn" do
      expect {
        post "/chat", params: { input: "#zeta-1234 do-it", uuid: conversation.uuid }
      }.not_to change(Turn, :count)
    end

    it "does NOT create an echo Event" do
      expect {
        post "/chat", params: { input: "#zeta-1234 do-it", uuid: conversation.uuid }
      }.not_to change(Event, :count)
    end

    it "enqueues FollowUpDispatchJob with the event id and rest (no turn_id)" do
      expect {
        post "/chat", params: { input: "#zeta-1234 do-it", uuid: conversation.uuid }
      }.to have_enqueued_job(FollowUpDispatchJob).with(
        source_event.id,
        hash_including(rest: "do-it")
      )
    end
  end

  # ── Append path ────────────────────────────────────────────────────────────

  context "append-mode follow-up (echo + turn created)" do
    let(:source_turn) do
      conversation.turns.create!(input_kind: :slash, input_text: "/confirm-thing", position: 99)
    end
    let!(:source_event) do
      Event.create_with_position!(
        conversation:, turn: source_turn, kind: "system",
        payload: {
          "reply_handle" => "eta-5678",
          "reply_target" => "ctrl_fake_append",
          "text"         => "Confirm this?"
        }
      )
    end

    it "returns 204 No Content" do
      post "/chat", params: { input: "#eta-5678 confirm", uuid: conversation.uuid }
      expect(response).to have_http_status(:no_content)
    end

    it "creates exactly one new Turn (the echo turn)" do
      expect {
        post "/chat", params: { input: "#eta-5678 confirm", uuid: conversation.uuid }
      }.to change(Turn, :count).by(1)
    end

    it "creates an echo Event" do
      post "/chat", params: { input: "#eta-5678 confirm", uuid: conversation.uuid }
      echo = Turn.last.events.find { |e| e.kind == "echo" }
      expect(echo).to be_present
    end

    it "enqueues FollowUpDispatchJob with event id, rest, and turn_id" do
      post "/chat", params: { input: "#eta-5678 confirm", uuid: conversation.uuid }
      turn_id = Turn.last.id
      expect(FollowUpDispatchJob).to have_been_enqueued.with(
        source_event.id,
        hash_including(rest: "confirm", turn_id: turn_id)
      )
    end
  end

  # ── Regression: existing confirmation path still works ─────────────────────

  context "legacy confirmation (#handle confirm|cancel with confirmation_handle)" do
    let(:conf_turn) do
      conversation.turns.create!(input_kind: :slash, input_text: "/disconnect @foo", position: 99)
    end
    let!(:conf_event) do
      Event.create_with_position!(
        conversation:, turn: conf_turn,
        kind: "confirmation",
        payload: {
          "command"             => "disconnect",
          "body"                => "Disconnect?",
          "confirmation_handle" => "theta-9090",
          "channel_id"          => 0,
          "authenticated"       => true
        }
      )
    end

    it "does NOT route via the follow-up engine (no FollowUpDispatchJob enqueued)" do
      expect {
        post "/chat", params: { input: "#theta-9090 confirm", uuid: conversation.uuid }
      }.not_to have_enqueued_job(FollowUpDispatchJob)
    end

    it "still enqueues ConfirmationDispatchJob" do
      expect {
        post "/chat", params: { input: "#theta-9090 confirm", uuid: conversation.uuid }
      }.to have_enqueued_job(ConfirmationDispatchJob).with(
        conf_event.id, hash_including(action: "confirm")
      )
    end

    it "flips processing to true on the confirmation event" do
      post "/chat", params: { input: "#theta-9090 confirm", uuid: conversation.uuid }
      expect(conf_event.reload.payload["processing"]).to be true
    end
  end

  # ── Non-matching input falls through to hashtag/async ─────────────────────

  context "unknown handle (not_found) — falls through to hashtag routing" do
    it "does not enqueue FollowUpDispatchJob" do
      expect {
        post "/chat", params: { input: "#nosuch-9999 anything", uuid: conversation.uuid }
      }.not_to have_enqueued_job(FollowUpDispatchJob)
    end

    it "routes normally (creates a Turn)" do
      expect {
        post "/chat", params: { input: "#nosuch-9999 anything", uuid: conversation.uuid }
      }.to change(Turn, :count).by(1)
    end
  end
end
