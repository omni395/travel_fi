class CreateVotes < ActiveRecord::Migration[8.1]
  def change
    create_table :votes do |t|
      t.references :votable, polymorphic: true, null: false
      t.references :user, null: false, foreign_key: true
      t.integer :value, null: false, default: 1

      t.timestamps
    end

    add_index :votes, [ :votable_type, :votable_id, :user_id ], unique: true, name: "index_votes_on_votable_and_user"
    add_index :votes, [ :votable_type, :votable_id, :value ]
  end
end
