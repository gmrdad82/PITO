# FB-test-infra (2026-05-22). Dev/test-only cable broadcast trampoline.
require "rails_helper"

RSpec.describe "POST /_test/broadcast", type: :request do
  # `allow_browser versions: :modern` on ApplicationController blocks
  # unknown UAs with a 403. Use a known-modern UA across this file.
  let(:modern_ua) do
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) " \
      "Chrome/130.0.0.0 Safari/537.36"
  end

  # Rails 8's `ActionDispatch::HostAuthorization` blocks the default
  # rack-test host `www.example.com` because pito's allowlist
  # (development.rb) is `localhost` + `127.0.0.1` + `::1` +
  # `app.pitomd.com` + `mcp.pitomd.com`. Switch every request in this
  # file to `localhost` so the middleware passes.
  before { host! "localhost" }

  it "is routable in the test environment" do
    expect(Rails.application.routes.recognize_path("/_test/broadcast", method: :post))
      .to include(controller: "test_broadcast", action: "create")
  end

  it "broadcasts via Pito::CableBroadcaster and returns 204" do
    expect(Pito::CableBroadcaster).to receive(:broadcast_status_bar)
      .with(hash_including("state" => "syncing"), kind: "sync")

    post "/_test/broadcast",
         params: { kind: "sync", payload: { state: "syncing" } }.to_json,
         headers: { "CONTENT_TYPE" => "application/json", "HTTP_USER_AGENT" => modern_ua }

    expect(response).to have_http_status(:no_content)
  end

  it "forwards arbitrary payload shapes (sidekiq stats variant)" do
    expect(Pito::CableBroadcaster).to receive(:broadcast_status_bar)
      .with(hash_including("busy" => 3, "enqueued" => 12, "retry" => 1), kind: "sidekiq")

    post "/_test/broadcast",
         params: { kind: "sidekiq", payload: { busy: 3, enqueued: 12, retry: 1 } }.to_json,
         headers: { "CONTENT_TYPE" => "application/json", "HTTP_USER_AGENT" => modern_ua }

    expect(response).to have_http_status(:no_content)
  end

  it "returns 403 when the env is forced to production at controller-level" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))

    post "/_test/broadcast",
         params: { kind: "sync", payload: { state: "synced" } }.to_json,
         headers: { "CONTENT_TYPE" => "application/json", "HTTP_USER_AGENT" => modern_ua }

    expect(response).to have_http_status(:forbidden)
  end

  it "skips authentication (allow_anonymous) — no login required" do
    # Endpoint is dev/test-only and must work without a session cookie.
    # If the auth gate ever leaks back on, this returns 302 -> /login.
    allow(Pito::CableBroadcaster).to receive(:broadcast_status_bar)

    post "/_test/broadcast",
         params: { kind: "sync", payload: {} }.to_json,
         headers: { "CONTENT_TYPE" => "application/json", "HTTP_USER_AGENT" => modern_ua }

    expect(response).to have_http_status(:no_content)
  end
end
