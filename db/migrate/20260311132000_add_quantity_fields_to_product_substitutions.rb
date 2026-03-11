# frozen_string_literal: true

class AddQuantityFieldsToProductSubstitutions < ActiveRecord::Migration[8.0]
  def change
    add_column :product_substitutions, :source_amount, :float
    add_column :product_substitutions, :source_unit, :string
    add_column :product_substitutions, :replacement_amount, :float
    add_column :product_substitutions, :replacement_unit, :string
    add_column :product_substitutions, :amount_multiplier, :float
  end
end
