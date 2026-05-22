# FB-test-infra (2026-05-22). Pito::Test::SleepJob spec.
require "rails_helper"

RSpec.describe Pito::Test::SleepJob do
  it "is a Sidekiq::Job" do
    expect(described_class.ancestors).to include(Sidekiq::Job)
  end

  it "disables retries (retry: 0) — test infra jobs must not pollute the retry set" do
    expect(described_class.sidekiq_options["retry"]).to eq(0)
  end

  it "enqueues on the default queue" do
    expect(described_class.sidekiq_options["queue"].to_s).to eq("default")
  end

  it "sleeps for the requested number of seconds" do
    job = described_class.new
    expect(job).to receive(:sleep).with(2)
    job.perform(2)
  end

  it "defaults to 5 seconds when called with no argument" do
    job = described_class.new
    expect(job).to receive(:sleep).with(5)
    job.perform
  end
end
