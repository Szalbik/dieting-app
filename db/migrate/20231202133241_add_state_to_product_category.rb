# frozen_string_literal: true

class AddStateToProductCategory < ActiveRecord::Migration[7.1]
  def change
    add_column :product_categories, :state, :boolean, default: false, null: false
  end
end
