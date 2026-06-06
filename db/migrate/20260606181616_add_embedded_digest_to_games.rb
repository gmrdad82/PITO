class AddEmbeddedDigestToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :embedded_digest, :string
  end
end
