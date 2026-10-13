# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MealPlanMealLocalizer do
  it 'copies a shared meal without setting the legacy diet_set_id on products' do
    diet_set = create(:diet_set)
    meal = create(:meal, diet_set: diet_set)
    product = create(:product, meal: meal, diet_set: nil)
    plan = create(:diet_set_plan, diet_set: diet_set)
    meal_plan = create(:meal_plan, diet_set_plan: plan, meal: meal)
    create(:meal_plan, diet_set_plan: create(:diet_set_plan, diet_set: diet_set, date: Date.tomorrow), meal: meal)

    copy = described_class.new(meal_plan: meal_plan).localize_product(product: product)

    expect(copy).not_to eq(product)
    expect(copy.diet_set_id).to be_nil
    expect(copy.meal.diet_set).to eq(diet_set)
  end
end
