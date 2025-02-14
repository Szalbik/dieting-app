class AddDateToShoppingCartItems < ActiveRecord::Migration[8.0]
  def change
    ShoppingCartItem.delete_all
    add_column :shopping_cart_items, :date, :date, null: false
  end
end
