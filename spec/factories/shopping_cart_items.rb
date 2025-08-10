# frozen_string_literal: true

FactoryBot.define do
  factory(:shopping_cart_item) do
    shopping_cart
    product
    meal_plan
    quantity { rand(1..5) }
    date { Date.current }
  end
end
