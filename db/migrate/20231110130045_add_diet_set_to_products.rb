class AddDietSetToProducts < ActiveRecord::Migration[7.1]
  def change
    add_reference :products, :diet_set, null: false, foreign_key: true
  end
end
