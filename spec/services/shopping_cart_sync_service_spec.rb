# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ShoppingCartSyncService do
  let(:user) { create(:user) }
  let(:shopping_cart) { user.shopping_cart || create(:shopping_cart, user: user) }
  let(:diet) { create(:diet, user: user) }
  let(:diet_set) { create(:diet_set, diet: diet) }
  let(:meal) { create(:meal, diet_set: diet_set) }
  let!(:product) { create(:product, meal: meal, diet_set: diet_set) }

  def sync!
    described_class.new(shopping_cart: shopping_cart, users: [user]).call
  end

  it 'preserves bought state across a resync instead of un-checking it' do
    diet_set_plan = create(:diet_set_plan, diet_set: diet_set, diet: diet, date: Date.current)
    create(:meal_plan, diet_set_plan: diet_set_plan, meal: meal, selected_for_cart: true)
    sync!

    item = shopping_cart.shopping_cart_items.find_by!(product: product)
    item.update!(bought: true)

    # Simulate "generate for a future day" triggering another full resync.
    sync!

    expect(shopping_cart.shopping_cart_items.find_by!(product: product).bought).to be true
  end

  it 'does not duplicate items when a stale DietSetPlan for the same date is still selected_for_cart' do
    stale_plan = create(:diet_set_plan, diet_set: diet_set, diet: diet, date: Date.current, created_at: 2.days.ago)
    create(:meal_plan, diet_set_plan: stale_plan, meal: meal, selected_for_cart: true)

    fresh_plan = create(:diet_set_plan, diet_set: diet_set, diet: diet, date: Date.current, created_at: 1.hour.ago)
    create(:meal_plan, diet_set_plan: fresh_plan, meal: meal, selected_for_cart: true)

    sync!

    expect(shopping_cart.shopping_cart_items.where(product: product, date: Date.current).count).to eq(1)
  end
end
