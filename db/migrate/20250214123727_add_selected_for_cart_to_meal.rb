class AddSelectedForCartToMeal < ActiveRecord::Migration[8.0]
  def change
    add_column :meals, :selected_for_cart, :boolean, default: true, null: false
  end
end
