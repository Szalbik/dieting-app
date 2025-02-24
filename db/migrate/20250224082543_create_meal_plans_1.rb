class CreateMealPlans1 < ActiveRecord::Migration[8.0]
  def change
    create_table :meal_plans do |t|
      t.references :diet_set_plan, null: false, foreign_key: true
      t.references :meal, null: false, foreign_key: true
      t.boolean :selected_for_cart, null: false, default: true

      t.timestamps
    end
  end
end
