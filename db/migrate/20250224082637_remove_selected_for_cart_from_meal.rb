# frozen_string_literal: true

class RemoveSelectedForCartFromMeal < ActiveRecord::Migration[8.0]
  def change
    remove_column :meals, :selected_for_cart, :boolean
  end
end
