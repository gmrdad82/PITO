class DropBundlesTables < ActiveRecord::Migration[8.0]
  def change
    if column_exists?(:video_game_links, :bundle_id)
      remove_index :video_game_links, :bundle_id, if_exists: true
      remove_column :video_game_links, :bundle_id, :bigint
    end
    drop_table :bundle_members, if_exists: true do |t|
      t.bigint :bundle_id, null: false
      t.bigint :game_id, null: false
      t.integer :position
      t.timestamps
    end
    drop_table :bundles, if_exists: true do |t|
      t.string :name, null: false
      t.timestamps
    end
  end
end
