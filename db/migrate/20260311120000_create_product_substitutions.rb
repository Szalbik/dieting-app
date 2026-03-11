# frozen_string_literal: true

class CreateProductSubstitutions < ActiveRecord::Migration[8.0]
  def change
    create_table :product_substitutions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :source_product, null: false
      t.string :replacement_product, null: false

      t.timestamps
    end

    add_index :product_substitutions,
              [:user_id, :source_product, :replacement_product],
              unique: true,
              name: 'index_product_substitutions_on_user_and_pair'
  end
end
