# frozen_string_literal: true

require "rails_helper"
require "rake"
require_relative "../../support/rake_spec_helper"

RSpec.describe "pito:tools:auth rake tasks", type: :rake do
  before(:all) { load_tasks }

  before do
    reenable("pito:tools:auth:enroll")
    reenable("pito:tools:auth:reset")
  end

  describe "pito:tools:auth:enroll" do
    it "prints the provisioning URI" do
      expect { Rake::Task["pito:tools:auth:enroll"].invoke }
        .to output(/otpauth:\/\/totp/).to_stdout
    end
  end

  describe "pito:tools:auth:reset" do
    it "prints a re-enroll hint" do
      expect { Rake::Task["pito:tools:auth:reset"].invoke }
        .to output(/pito:tools:auth:enroll/).to_stdout
    end
  end
end
