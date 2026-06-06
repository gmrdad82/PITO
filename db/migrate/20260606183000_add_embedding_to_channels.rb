class AddEmbeddingToChannels < ActiveRecord::Migration[8.1]
  def change
    add_column :channels, :summary_embedding, :vector, limit: 1024
    add_column :channels, :keywords, :text
    add_column :channels, :tags, :text, array: true, default: [], null: false

    add_index :channels, :summary_embedding,
              name:    "index_channels_on_summary_embedding_hnsw",
              opclass: :vector_cosine_ops,
              using:   :hnsw
  end
end
