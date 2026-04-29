# frozen_string_literal: true

class CreateProductNameSuggestions < ActiveRecord::Migration[8.0]
  def change
    create_table :product_name_suggestions do |t|
      t.integer  :user_id,              null: false
      t.string   :raw_name,             null: false
      t.integer  :canonical_product_id
      t.float    :confidence,           null: false, default: 0.0
      t.string   :match_type,           null: false
      t.string   :source,               null: false
      t.string   :status,               null: false, default: "pending"
      t.integer  :occurrence_count,     null: false, default: 1

      t.timestamps
    end

    add_index :product_name_suggestions, :user_id
    add_index :product_name_suggestions, :status
    add_index :product_name_suggestions, :canonical_product_id
    add_index :product_name_suggestions,
              %i[user_id raw_name],
              unique: true,
              where: "status = 'pending'",
              name: "idx_pns_unique_pending_per_user_raw_name"
  end
end
