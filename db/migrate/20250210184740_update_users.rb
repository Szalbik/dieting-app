class UpdateUsers < ActiveRecord::Migration[8.0]
  def change
    rename_column :users, :email, :email_address
    change_column_null :users, :email_address, false
    change_column_null :users, :password_digest, false
    add_index :users, :email_address, unique: true
  end
end
