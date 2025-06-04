# frozen_string_literal: true

# This migration fixes the foreign key constraint for the product_categories table
# to ensure that it properly references the categories table with a cascade delete option.
# This is necessary to maintain referential integrity and ensure that when a category is deleted,
# all associated product categories are also deleted.
class FixProductCategoriesCategoryFk < ActiveRecord::Migration[8.0]
  def change
    remove_foreign_key :product_categories, :categories
    add_foreign_key :product_categories, :categories, on_delete: :cascade
  end
end
