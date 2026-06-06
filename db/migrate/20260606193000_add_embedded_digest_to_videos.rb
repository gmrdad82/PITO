class AddEmbeddedDigestToVideos < ActiveRecord::Migration[8.1]
  def change
    add_column :videos, :embedded_digest, :string
  end
end
