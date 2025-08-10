# frozen_string_literal: true

FactoryBot.define do
  factory(:product) do
    meal
    name { "Product #{Faker::Commerce.product_name}" }
    unit
    diet_set
  end
end
