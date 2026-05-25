class AddPausedTargetsToAppSettings < ActiveRecord::Migration[8.1]
  # 2026-05-25 (pause-from-sync) — `paused_targets` is a JSON-serialized
  # text column on the singleton row. Stores the set of dot-namespaced
  # sync targets the user has explicitly paused (e.g. `["home.stack",
  # "home.stack.meilisearch"]`). The column lives on `app_settings`
  # rather than as KV rows because:
  #
  #   1. The set is always read/written atomically by `Pito::SyncState`.
  #   2. The singleton lock pattern (`WITH (LOCK = ...)` → `update!`)
  #      used by `mark_paused!` / `mark_resumed!` already lives on this
  #      table.
  #
  # Default `"[]"` means "nothing paused" — the column is always
  # present and never NULL, matching the `reindex_running` pattern.
  def change
    add_column :app_settings, :paused_targets, :text, default: "[]", null: false
  end
end
