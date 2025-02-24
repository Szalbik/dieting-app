class RenameMealPlansToDietSetPlans < ActiveRecord::Migration[8.0]
  def change
    rename_table :meal_plans, :diet_set_plans
  end
end
