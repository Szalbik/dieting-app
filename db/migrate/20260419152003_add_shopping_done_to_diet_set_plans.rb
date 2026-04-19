class AddShoppingDoneToDietSetPlans < ActiveRecord::Migration[8.0]
  def change
    add_column :diet_set_plans, :shopping_done, :boolean, default: false, null: false
  end
end
