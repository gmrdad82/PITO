class DropMasterSyncPausedFromAppSettings < ActiveRecord::Migration[8.1]
  # Z2e (2026-05-25) — drop the `master_sync_paused` boolean that powered
  # the multi-state sync machine (idle/active/syncing/paused/uncertain/mixed).
  # The 3-state indicator (synced/syncing/disconnected) is pure JS; no DB flag
  # is needed for sync state. The column is safe to drop with no data concern
  # because it only ever held `false` (the default) in production — the pause
  # flow was never user-accessible in a released build.
  def change
    remove_column :app_settings, :master_sync_paused, :boolean
  end
end
