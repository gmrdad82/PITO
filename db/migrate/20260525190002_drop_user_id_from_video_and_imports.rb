# Z1-ext — drop user_id FKs that blocked the `users` table drop in Z1.
#
# The Z1 migration dropped the `users` table but the FK references on these
# four tables prevented the DROP TABLE from completing. This migration
# removes those FKs and their associated index + column, then the parent
# migration's DROP TABLE can proceed cleanly.
class DropUserIdFromVideoAndImports < ActiveRecord::Migration[8.0]
  def change
    remove_reference :rejected_video_imports, :user, foreign_key: true, index: true, if_exists: true
    remove_reference :video_change_logs,      :user, foreign_key: true, index: true, if_exists: true
    remove_reference :video_diffs,            :user, foreign_key: true, index: true, if_exists: true
    remove_reference :video_game_links,       :user, foreign_key: true, index: true, if_exists: true
    # ImportJob.enqueued_by_id also references users (Phase 22)
    remove_reference :import_jobs,            :enqueued_by, foreign_key: { to_table: :users }, index: true, if_exists: true
    # CalendarEntry.created_by_user_id also references users
    remove_reference :calendar_entries,       :created_by_user, foreign_key: { to_table: :users }, index: true, if_exists: true
    # ChannelChangeLog.changed_by_user_id also references users
    remove_reference :channel_change_logs,    :changed_by_user, foreign_key: { to_table: :users }, index: true, if_exists: true
    # Notification.created_by_user_id also references users
    remove_reference :notifications,          :created_by_user, foreign_key: { to_table: :users }, index: true, if_exists: true
    # MilestoneRule.created_by_user_id also references users
    remove_reference :milestone_rules,        :created_by_user, foreign_key: { to_table: :users }, index: true, if_exists: true
  end
end
