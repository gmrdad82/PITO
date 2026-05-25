# Adds a `category` column to notifications so rows can be classified as
# channel / game / system / manual. Default is "system" so all pre-existing
# rows get a valid value without a backfill job.
class AddCategoryToNotifications < ActiveRecord::Migration[8.0]
  def change
    add_column :notifications, :category, :string, null: false, default: "system"
    add_index  :notifications, :category
  end
end
