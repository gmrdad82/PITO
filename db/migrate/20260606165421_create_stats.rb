# frozen_string_literal: true

# P4 — Polymorphic Stat model.
#
# One row per (entity, kind). `value` is a bigint count (subscribers /
# views); `synced_at` records when the value was last refreshed from its
# source. The unique index doubles as the upsert conflict target used by
# `Pito::Stats.set`.
class CreateStats < ActiveRecord::Migration[8.1]
  def change
    create_table :stats do |t|
      t.string :entity_type, null: false
      t.bigint :entity_id, null: false
      t.string :kind, null: false
      t.bigint :value
      t.datetime :synced_at

      t.timestamps
    end

    add_index :stats, %i[entity_type entity_id kind], unique: true,
                                                      name: "index_stats_on_entity_and_kind"
  end
end
