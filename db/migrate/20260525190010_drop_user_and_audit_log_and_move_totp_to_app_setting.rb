# Z1 — Auth simplification.
#
# Drops the multi-user `users` + `auth_audit_logs` tables (pito is
# single-install; the owner identity collapses into `AppSetting`).
# Removes the FK references from `sessions` and `totp_backup_codes`
# that pointed to `users`. Adds TOTP columns to `app_settings` so the
# singleton row becomes the sole TOTP carrier.
class DropUserAndAuditLogAndMoveTotpToAppSetting < ActiveRecord::Migration[8.0]
  def change
    remove_reference :sessions,          :user, foreign_key: true, index: true, if_exists: true
    remove_reference :totp_backup_codes, :user, foreign_key: true, index: true, if_exists: true

    drop_table :auth_audit_logs, if_exists: true do |t|
      t.bigint   "acting_user_id", null: false
      t.integer  "action",         null: false
      t.datetime "created_at",     null: false
      t.jsonb    "metadata",       default: {}, null: false
      t.integer  "source_surface", null: false
      t.bigint   "target_id",      null: false
      t.string   "target_type",    null: false
      t.datetime "updated_at",     null: false
      t.index [ "acting_user_id" ], name: "index_auth_audit_logs_on_acting_user_id"
      t.index [ "action" ],         name: "index_auth_audit_logs_on_action"
      t.index [ "created_at" ],     name: "index_auth_audit_logs_on_created_at"
      t.index [ "source_surface" ], name: "index_auth_audit_logs_on_source_surface"
      t.index [ "target_type", "target_id" ], name: "index_auth_audit_logs_on_target_type_and_target_id"
    end

    drop_table :users, if_exists: true, force: :cascade do |t|
      t.datetime "created_at",              null: false
      t.datetime "last_digest_run_at",      default: -> { "CURRENT_TIMESTAMP" }, null: false
      t.datetime "last_login_at"
      t.string   "password_digest",         null: false
      t.string   "time_zone",               default: "Etc/UTC", null: false
      t.datetime "totp_disabled_at"
      t.datetime "totp_enabled_at"
      t.bigint   "totp_last_used_step"
      t.text     "totp_seed_encrypted"
      t.datetime "updated_at",              null: false
      t.citext   "username",                null: false
      t.index [ "last_digest_run_at" ], name: "index_users_on_last_digest_run_at"
      t.index [ "last_login_at" ],      name: "index_users_on_last_login_at"
      t.index [ "username" ],           name: "index_users_on_username", unique: true
    end

    add_column :app_settings, :totp_seed_encrypted,  :text
    add_column :app_settings, :totp_enabled_at,       :datetime
    add_column :app_settings, :totp_disabled_at,      :datetime
    add_column :app_settings, :totp_last_used_step,   :integer
  end
end
