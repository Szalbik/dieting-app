# frozen_string_literal: true

class AllowNullActiveShoppingCartIdOnUsers < ActiveRecord::Migration[8.0]
  def change
    change_column_null :users, :active_shopping_cart_id, true
  end
end
