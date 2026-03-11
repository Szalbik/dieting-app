# frozen_string_literal: true

class AddBaseProductNameToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :base_product_name, :string
  end
end
