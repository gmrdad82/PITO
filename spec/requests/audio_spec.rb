# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Audio integration", type: :request do
  it "mounts the audio controller on the body" do
    get root_path
    expect(response.body).to include('data-controller="pito--audio"')
  end

  it "includes the audio hint + label in the mini status" do
    get root_path
    expect(response.body).to include("ctrl+m")
    expect(response.body).to include("mute")
  end

  it "includes the audio label element for JS color toggle" do
    get root_path
    expect(response.body).to include('id="pito-audio-label"')
  end

  it "serves send.mp3 as a static asset" do
    get "/sounds/send.mp3"
    expect(response).to have_http_status(:ok)
    expect(response.content_type).to eq("audio/mpeg")
  end

  it "serves receive.mp3 as a static asset" do
    get "/sounds/receive.mp3"
    expect(response).to have_http_status(:ok)
    expect(response.content_type).to eq("audio/mpeg")
  end
end
