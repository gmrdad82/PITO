# frozen_string_literal: true

# Thumbnails are now served from OUR ActiveStorage copy (Video#thumbnail),
# attached during sync/import via Video::Thumbnail::Ingest. The raw YouTube CDN
# URL is no longer stored — we never hotlink i.ytimg.com (it 429s).
class DropThumbnailUrlFromVideos < ActiveRecord::Migration[8.1]
  def change
    remove_column :videos, :thumbnail_url, :string
  end
end
