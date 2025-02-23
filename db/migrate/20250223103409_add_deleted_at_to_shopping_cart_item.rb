class AddDeletedAtToShoppingCartItem < ActiveRecord::Migration[8.0]
  def change
    add_column :shopping_cart_items, :deleted_at, :datetime
    add_index :shopping_cart_items, :deleted_at
  end
end
