# frozen_string_literal: true

class CreateIngredientMeasures < ActiveRecord::Migration[7.0]
  def change
    create_table :ingredient_measures do |t|
      t.float :amount
      t.string :unit
      t.references :product, null: false, foreign_key: true

      t.timestamps
    end
  end
end
