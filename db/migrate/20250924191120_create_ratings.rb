class CreateRatings < ActiveRecord::Migration[8.0]
  def change
    create_table :ratings do |t|
      t.references :post, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :value, null: false

      t.timestamps
    end

    # Each user only can rate one post
    add_index :ratings, [ :post_id, :user_id ], unique: true

    # Constraint: values between 1 and 5
    add_check_constraint :ratings,
                         "value BETWEEN 1 AND 5",
                         name: "ratings_value_range"
  end
end
