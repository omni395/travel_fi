class AddModerationSourceToPois < ActiveRecord::Migration[8.1]
  def change
    add_column :pois, :moderation_source, :integer, default: 0, null: false
  end
end
