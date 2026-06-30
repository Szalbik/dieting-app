# frozen_string_literal: true

class AddEatenToMealPlans < ActiveRecord::Migration[8.0]
  def change
    add_column :meal_plans, :eaten, :boolean, default: false, null: false
  end
end
