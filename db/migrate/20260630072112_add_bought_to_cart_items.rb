# frozen_string_literal: true

class AddBoughtToCartItems < ActiveRecord::Migration[8.0]
  def change
    add_column :shopping_cart_items, :bought, :boolean, default: false, null: false
    add_column :custom_cart_items, :bought, :boolean, default: false, null: false
  end
end
