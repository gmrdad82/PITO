class AddPolymorphicTargetToBulkOperationItems < ActiveRecord::Migration[8.1]
  def change
    add_column :bulk_operation_items, :target_type, :string
    add_column :bulk_operation_items, :target_id, :bigint
    add_index :bulk_operation_items, [ :target_type, :target_id ]

    # Backfill existing video_id references
    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE bulk_operation_items
          SET target_type = 'Video', target_id = video_id
          WHERE video_id IS NOT NULL
        SQL
      end
    end

    # Make video_id optional (was required before)
    change_column_null :bulk_operation_items, :video_id, true
  end
end
