# frozen_string_literal: true

# Client-minted id so a replayed offline "add own item" is a no-op instead of a duplicate.
class AddClientIdToCustomCartItems < ActiveRecord::Migration[8.0]
  def change
    add_column :custom_cart_items, :client_id, :string
    add_index :custom_cart_items, %i[shopping_cart_id client_id], unique: true
  end
end
