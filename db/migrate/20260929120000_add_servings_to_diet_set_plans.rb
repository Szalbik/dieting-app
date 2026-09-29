# frozen_string_literal: true

class AddServingsToDietSetPlans < ActiveRecord::Migration[8.0]
  def change
    add_column :diet_set_plans, :servings, :integer, null: false, default: 1
    add_check_constraint :diet_set_plans, 'servings BETWEEN 1 AND 10', name: 'diet_set_plans_servings_range'
  end
end
