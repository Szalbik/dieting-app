# frozen_string_literal: true

# This migration fixes the foreign key constraint for the products table to ensure that
# it properly references the meals table with a nullify option.
# This is necessary to maintain referential integrity and ensure that when a meal is deleted,
# the associated products are not deleted but their meal_id is set to null.
class FixProductCategoriesProductFk < ActiveRecord::Migration[8.0]
  def change
    remove_foreign_key :product_categories, :products
    add_foreign_key :product_categories, :products, on_delete: :cascade
  end
end
