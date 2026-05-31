# frozen_string_literal: true

require "rails_helper"
require "rake"
require_relative "../../support/rake_spec_helper"

RSpec.describe "pito:test:seeds:prepare", type: :rake do
  before(:all) { load_tasks }

  before { reenable("pito:test:seeds:prepare") }

  it "writes YAML files for every table" do
    suppress_output { Rake::Task["pito:test:seeds:prepare"].invoke }

    expect(Rails.root.join("db/test_seeds/manifest.yml")).to exist
    expect(Rails.root.join("db/test_seeds/channels.yml")).to exist
    expect(Rails.root.join("db/test_seeds/games.yml")).to exist
  end

  it "records row counts in the manifest" do
    create_list(:channel, 2)
    create(:game)

    suppress_output { Rake::Task["pito:test:seeds:prepare"].invoke }

    manifest = YAML.load_file(Rails.root.join("db/test_seeds/manifest.yml"))
    expect(manifest[:tables]["channels"]).to eq(2)
    expect(manifest[:tables]["games"]).to be >= 1
  end
end
