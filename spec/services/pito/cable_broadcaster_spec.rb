# FB-test-infra (2026-05-22). Pito::CableBroadcaster spec.
require "rails_helper"

RSpec.describe Pito::CableBroadcaster do
  describe ".broadcast_status_bar" do
    it "broadcasts to the canonical pito:status_bar channel with the default kind 'data'" do
      expect(ActionCable.server).to receive(:broadcast).with(
        "pito:status_bar",
        hash_including(kind: "data", payload: { busy: 1 }, ts: kind_of(String))
      )
      described_class.broadcast_status_bar({ busy: 1 })
    end

    it "accepts an explicit kind: kwarg and stringifies it" do
      expect(ActionCable.server).to receive(:broadcast).with(
        "pito:status_bar",
        hash_including(kind: "sync", payload: { state: "syncing" })
      )
      described_class.broadcast_status_bar({ state: "syncing" }, kind: :sync)
    end

    it "always emits an ISO8601 ts on the envelope" do
      captured = nil
      allow(ActionCable.server).to receive(:broadcast) { |_, envelope| captured = envelope }
      described_class.broadcast_status_bar({ ok: true })
      expect(captured[:ts]).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end

    it "pins to STATUS_BAR_CHANNEL constant" do
      expect(described_class::STATUS_BAR_CHANNEL).to eq("pito:status_bar")
    end
  end

  describe ".broadcast_panel" do
    it "broadcasts to a pito:-prefixed channel with kind + payload + ts" do
      expect(ActionCable.server).to receive(:broadcast).with(
        "pito:home:stack",
        hash_including(kind: "indeterminate", payload: { step: 2 }, ts: kind_of(String))
      )
      described_class.broadcast_panel("pito:home:stack", kind: "indeterminate", payload: { step: 2 })
    end

    it "raises ArgumentError for a channel name that does not start with pito:" do
      expect {
        described_class.broadcast_panel("home:stack", kind: "x", payload: {})
      }.to raise_error(ArgumentError, /must start with pito:/)
    end

    it "accepts deeper sub-panel grammar (pito:home:stack:redis)" do
      expect(ActionCable.server).to receive(:broadcast).with("pito:home:stack:redis", anything)
      described_class.broadcast_panel("pito:home:stack:redis", kind: "complete", payload: {})
    end
  end
end
