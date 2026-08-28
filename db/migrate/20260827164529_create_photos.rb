class CreatePhotos < ActiveRecord::Migration[8.1]
  def change
    create_table :photos do |t|
      t.references :poi, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :photos, [ :poi_id, :position ]
  end
end
