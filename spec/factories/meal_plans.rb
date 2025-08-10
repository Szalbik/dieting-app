# frozen_string_literal: true

FactoryBot.define do
  factory(:meal_plan) do
    diet_set_plan
    meal
    selected_for_cart { true }
  end
end
