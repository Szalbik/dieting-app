# frozen_string_literal: true

# This migration fixes the foreign key constraint for the meal_plans table to ensure that
# it properly references the meals table with a cascade delete option.
# This is necessary to maintain referential integrity and ensure that when a meal is deleted,
# all associated meal plans are also deleted.
class FixMealPlanForeignKey < ActiveRecord::Migration[8.0]
  def change
    remove_foreign_key :meal_plans, :meals
    add_foreign_key :meal_plans, :meals, on_delete: :cascade
  end
end
