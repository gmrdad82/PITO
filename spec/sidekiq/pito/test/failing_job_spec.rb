# FB-test-infra (2026-05-22). Pito::Test::FailingJob spec.
require "rails_helper"

RSpec.describe Pito::Test::FailingJob do
  it "is a Sidekiq::Job" do
    expect(described_class.ancestors).to include(Sidekiq::Job)
  end

  it "retries 3 times — populates the retry set with back-off windows" do
    expect(described_class.sidekiq_options["retry"]).to eq(3)
  end

  it "enqueues on the default queue" do
    expect(described_class.sidekiq_options["queue"].to_s).to eq("default")
  end

  it "raises on every perform attempt" do
    expect { described_class.new.perform }.to raise_error(RuntimeError, /intentional failure/)
  end
end
