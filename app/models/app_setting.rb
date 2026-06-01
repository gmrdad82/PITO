# frozen_string_literal: true

# Install-wide settings.
#
# Two row shapes share this table:
#   1. Key/value rows — anything addressable by string key.
#   2. The singleton row (`key = "__singleton__"`) — carries TOTP state
#      and pre-allocated encrypted API key columns. All class-level
#      helpers route through `singleton_row`.
#
# API-key reads fall through to ENV vars when the singleton row column
# is blank. Lets keys be supplied via the environment without a forced
# DB write.
class AppSetting < ApplicationRecord
  SINGLETON_KEY = "__singleton__"

  encrypts :value, deterministic: true
  encrypts :totp_seed_encrypted
  encrypts :google_oauth_client_id
  encrypts :google_oauth_client_secret
  encrypts :voyage_api_key

  validates :key,
            uniqueness: { case_sensitive: false },
            allow_nil: true

  def self.get(key)
    find_by(key: key)&.value
  end

  def self.set(key, value)
    record = find_or_initialize_by(key: key)
    record.update!(value: value)
    record
  end

  def self.singleton_row
    row = find_by(key: SINGLETON_KEY)
    return row if row

    create!(key: SINGLETON_KEY)
  rescue ActiveRecord::RecordNotUnique
    find_by!(key: SINGLETON_KEY)
  end

  # ── TOTP ─────────────────────────────────────────────────────────────

  def self.enroll_totp!(seed:)
    singleton_row.update!(
      totp_seed_encrypted: seed,
      totp_last_used_step: nil
    )
  end

  def self.totp_seed
    singleton_row.totp_seed_encrypted
  end

  # ── API keys ───────────────────────────────────────────────────────

  def self.google_oauth_client_id
    singleton_row.google_oauth_client_id
  end

  def self.google_oauth_client_secret
    singleton_row.google_oauth_client_secret
  end

  def self.voyage_api_key
    singleton_row.voyage_api_key
  end
end
