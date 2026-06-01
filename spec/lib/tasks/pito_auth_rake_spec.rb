# frozen_string_literal: true

require "rails_helper"
require "rake"
require_relative "../../support/rake_spec_helper"

RSpec.describe "pito:tools:auth rake tasks", type: :rake do
  before(:all) { load_tasks }

  before do
    reenable("pito:tools:auth:enroll")
  end

  describe "pito:tools:auth:enroll" do
    it "prints the provisioning URI" do
      expect { Rake::Task["pito:tools:auth:enroll"].invoke }
        .to output(/otpauth:\/\/totp/).to_stdout
    end
  end
end
