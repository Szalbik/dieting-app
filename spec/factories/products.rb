# frozen_string_literal: true

FactoryBot.define do
  factory(:product) do
    meal
    name { "Product #{Faker::Commerce.product_name}" }
    unit
    diet_set

    trait :with_category do
      after(:create) do |product|
        category = create(:category, name: "Test Category #{rand(1000)}")
        create(:product_category, product: product, category: category)
      end
    end
  end
end
