class AddMealToProduct < ActiveRecord::Migration[8.0]
  def change
    add_reference :products, :meal, null: false, foreign_key: true
  end
end
