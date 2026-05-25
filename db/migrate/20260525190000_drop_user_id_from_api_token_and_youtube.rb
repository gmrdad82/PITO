class DropUserIdFromApiTokenAndYoutube < ActiveRecord::Migration[8.0]
  def change
    remove_reference :api_tokens, :user, foreign_key: true, index: true, if_exists: true
    remove_reference :youtube_connections, :user, foreign_key: true, index: true, if_exists: true
    remove_reference :youtube_api_calls, :user, foreign_key: true, index: true, if_exists: true
  end
end
