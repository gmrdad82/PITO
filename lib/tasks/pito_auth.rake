# Pito auth operator tasks — TOTP enrollment.
#
# These tasks target the singleton-owner model: AppSetting holds the TOTP
# seed. Operator-only shell surface; no web equivalent exists.
# The owner authenticates in the browser by typing
# `/authenticate <6-digit code>` into the chatbox.
#
# Usage:
#   bin/rails pito:tools:auth:enroll   # fresh TOTP seed (overwrites any existing)
namespace :pito do
  namespace :tools do
  namespace :auth do
    desc "Enroll the singleton owner with a fresh TOTP seed (overwrites existing)."
    task enroll: :environment do
      seed = ROTP::Base32.random_base32
      AppSetting.enroll_totp!(seed: seed)

      issuer  = "pito"
      account = "owner"
      otpauth_uri = ROTP::TOTP.new(seed, issuer: issuer).provisioning_uri(account)

      puts "TOTP enrolled."
      puts ""
      puts "Paste this into your authenticator app (manual entry, or as URI):"
      puts "  #{otpauth_uri}"
      puts ""
      puts "Or enter the raw secret manually:"
      puts "  #{seed}"
      puts ""
      puts "Done. In your browser, type /authenticate <6-digit code> in the chatbox."
    end
  end
  end
end
