class AddCommunityRejectedToPois < ActiveRecord::Migration[8.1]
  def change
    add_column :pois, :community_rejected, :boolean, default: false, null: false
  end
end
