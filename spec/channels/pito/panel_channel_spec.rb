require "rails_helper"

RSpec.describe Pito::PanelChannel, type: :channel do
  let(:user) { instance_double("User", present?: true) }

  describe "#subscribed" do
    context "when current_user is absent" do
      before { stub_connection(current_user: nil) }

      it "rejects the subscription" do
        subscribe(screen: "home", name: "security")
        expect(subscription).to be_rejected
      end
    end

    context "when current_user is present" do
      before { stub_connection(current_user: user) }

      it "accepts a subscription with whitelisted screen + panel" do
        subscribe(screen: "home", name: "security")
        expect(subscription).to be_confirmed
      end

      it "streams from the canonical `pito:<screen>:<panel>` broadcasting" do
        subscribe(screen: "home", name: "security")
        expect(subscription).to have_stream_from("pito:home:security")
      end

      it "streams the correct broadcasting for a non-home screen" do
        subscribe(screen: "videos", name: "latest_videos")
        expect(subscription).to have_stream_from("pito:videos:latest_videos")
      end

      it "accepts every panel in the allowlist" do
        described_class::ALLOWED_PANELS.each do |panel|
          subscribe(screen: "home", name: panel)
          expect(subscription).to be_confirmed, "expected `#{panel}` to be accepted"
        end
      end

      it "rejects when screen is not in ALLOWED_SCREENS" do
        subscribe(screen: "settings", name: "security")
        expect(subscription).to be_rejected
      end

      it "rejects when panel name is not in ALLOWED_PANELS" do
        subscribe(screen: "home", name: "logging")
        expect(subscription).to be_rejected
      end

      it "rejects when panel name contains characters that fail the regex" do
        stub_const("#{described_class.name}::ALLOWED_PANELS", described_class::ALLOWED_PANELS + [ "bad-name" ])
        subscribe(screen: "home", name: "bad-name")
        expect(subscription).to be_rejected
      end

      it "rejects when params are missing entirely" do
        subscribe
        expect(subscription).to be_rejected
      end
    end
  end

  describe "allowlists" do
    it "exposes ALLOWED_SCREENS as a frozen array of home/videos/games" do
      expect(described_class::ALLOWED_SCREENS).to eq(%w[home videos games])
      expect(described_class::ALLOWED_SCREENS).to be_frozen
    end

    it "exposes ALLOWED_PANELS as a frozen array" do
      expect(described_class::ALLOWED_PANELS).to be_frozen
      expect(described_class::ALLOWED_PANELS).to include(
        "security", "notifications", "stack", "channels_overview",
        "latest_videos", "games_releasing", "notifications_feed", "calendar"
      )
    end
  end
end
