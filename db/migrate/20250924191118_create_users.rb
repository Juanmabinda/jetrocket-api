class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :login, null: false

      t.timestamps
    end
    # Unique index
    add_index :users, :login, unique: true

    # constraint a nivel DB para evitar strings vacíos
    add_check_constraint :users, "length(btrim(login)) > 0", name: "users_login_nonempty"
  end
end
