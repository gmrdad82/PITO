# FB-test-infra (2026-05-22). Pito::Test::ScheduledJob spec.
require "rails_helper"

RSpec.describe Pito::Test::ScheduledJob do
  it "is a Sidekiq::Job" do
    expect(described_class.ancestors).to include(Sidekiq::Job)
  end

  it "disables retries (retry: 0)" do
    expect(described_class.sidekiq_options["retry"]).to eq(0)
  end

  it "enqueues on the default queue" do
    expect(described_class.sidekiq_options["queue"].to_s).to eq("default")
  end

  it "performs a no-op without raising" do
    expect { described_class.new.perform }.not_to raise_error
  end
end
