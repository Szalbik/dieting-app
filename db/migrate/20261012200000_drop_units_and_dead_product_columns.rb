# frozen_string_literal: true

class DropUnitsAndDeadProductColumns < ActiveRecord::Migration[8.0]
  def change
    remove_reference :products, :associated_product, type: :integer, index: true,
                                                     foreign_key: { to_table: :products }
    remove_reference :products, :unit, type: :integer, index: true, foreign_key: true
    drop_table :units do |t|
      t.string :name
      t.timestamps
    end
  end
end
