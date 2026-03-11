# frozen_string_literal: true

class CreateSubstitutionProductMatches < ActiveRecord::Migration[8.0]
  def change
    create_table :substitution_product_matches do |t|
      t.references :user, null: false, foreign_key: true
      t.string :source_product, null: false
      t.string :matched_product_name, null: false
      t.float :confidence

      t.timestamps
    end

    add_index :substitution_product_matches,
              [:user_id, :source_product, :matched_product_name],
              unique: true,
              name: 'index_substitution_product_matches_on_user_source_and_match'
  end
end
