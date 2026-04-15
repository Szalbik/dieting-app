# frozen_string_literal: true

class AllowMealIdToBeNil < ActiveRecord::Migration[8.0]
  def change
    change_column :products, :meal_id, :integer, null: true
  end
end
