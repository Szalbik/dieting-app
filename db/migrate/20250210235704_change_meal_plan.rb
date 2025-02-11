class ChangeMealPlan < ActiveRecord::Migration[8.0]
  def change
    add_reference :meal_plans, :diet_set, null: false, foreign_key: true
  end
end
