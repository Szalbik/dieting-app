# frozen_string_literal: true

FactoryBot.define do
  factory(:meal_plan_product_substitution) do
    user
    meal_plan
    product
    source_product { 'Tunczyk' }
    replacement_product { 'Losos' }
  end
end
