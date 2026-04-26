require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#nav_link" do
    it "returns a link when not on the current page" do
      allow(helper).to receive(:current_page?).with("/channels").and_return(false)
      result = helper.nav_link("Channels", "/channels")
      expect(result).to include("<a")
      expect(result).to include("Channels")
      expect(result).to include("/channels")
    end

    it "returns a span when on the current page" do
      allow(helper).to receive(:current_page?).with("/").and_return(true)
      result = helper.nav_link("Dashboard", "/")
      expect(result).to include("<span")
      expect(result).to include("Dashboard")
      expect(result).not_to include("<a")
    end
  end
end
