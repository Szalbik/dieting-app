# frozen_string_literal: true

# This migration adds nutrition and type columns to the meals table.
class AddNutritionAndTypeToMeals < ActiveRecord::Migration[8.0]
  def change
    add_column :meals, :meal_type, :string
    add_column :meals, :kcal, :integer
    add_column :meals, :protein, :float
    add_column :meals, :fat, :float
    add_column :meals, :carbs, :float
  end
end
