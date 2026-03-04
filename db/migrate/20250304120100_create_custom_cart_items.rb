# frozen_string_literal: true

class CreateCustomCartItems < ActiveRecord::Migration[8.0]
  def change
    create_table :custom_cart_items do |t|
      t.references :shopping_cart, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :quantity, default: 1, null: false
      t.string :unit, default: 'szt'

      t.timestamps
    end

    add_index :custom_cart_items, [:shopping_cart_id, :name]
  end
end
