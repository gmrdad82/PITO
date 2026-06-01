# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Logout", type: :request do
  let!(:seed) { ROTP::Base32.random_base32 }

  before { AppSetting.enroll_totp!(seed: seed) }

  it "clears the session cookie and redirects to root" do
    # First authenticate
    totp = ROTP::TOTP.new(seed)
    post "/chat", params: { input: "/authenticate #{totp.now}" }
    expect(cookies["pito_session"]).to be_present

    # Then logout
    delete "/logout"
    expect(response).to redirect_to(root_path)
    expect(cookies["pito_session"]).to be_blank
  end
end
