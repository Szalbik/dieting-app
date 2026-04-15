# frozen_string_literal: true

class CreateCanonicalProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :canonical_products do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    add_index :canonical_products, %i[user_id name], unique: true

    create_table :canonical_product_aliases do |t|
      t.references :canonical_product, null: false, foreign_key: true
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.string :stem_signature, null: false

      t.timestamps
    end

    add_index :canonical_product_aliases, %i[canonical_product_id name], unique: true,
                                                                         name: 'idx_canonical_aliases_on_product_and_name'
    add_index :canonical_product_aliases, :normalized_name
    add_index :canonical_product_aliases, :stem_signature

    add_reference :products, :canonical_product, foreign_key: true
    add_reference :products, :base_canonical_product, foreign_key: { to_table: :canonical_products }

    add_reference :product_substitutions, :source_canonical_product, foreign_key: { to_table: :canonical_products }
    add_reference :product_substitutions, :replacement_canonical_product, foreign_key: { to_table: :canonical_products }
  end
end
