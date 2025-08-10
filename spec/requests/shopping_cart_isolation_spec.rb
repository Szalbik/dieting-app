# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Shopping Cart Isolation', type: :request do
  describe 'shopping cart isolation between users' do
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }
    let(:diet1) { create(:diet, user: user1) }
    let(:diet2) { create(:diet, user: user2) }
    let(:diet_set1) { create(:diet_set, diet: diet1) }
    let(:diet_set2) { create(:diet_set, diet: diet2) }
    let(:meal1) { create(:meal, diet_set: diet_set1) }
    let(:meal2) { create(:meal, diet_set: diet_set2) }
    let(:product1) { create(:product, meal: meal1) }
    let(:product2) { create(:product, meal: meal2) }
    let(:meal_plan1) { create(:meal_plan, meal: meal1, selected_for_cart: true) }
    let(:meal_plan2) { create(:meal_plan, meal: meal2, selected_for_cart: true) }

    before do
      # Create diet set plans for both users
      create(:diet_set_plan, diet_set: diet_set1, date: Date.current, created_at: 1.day.ago)
      create(:diet_set_plan, diet_set: diet_set2, date: Date.current, created_at: 1.day.ago)

      # Add items to both users' carts
      user1_cart = user1.shopping_cart
      create(:shopping_cart_item,
             shopping_cart: user1_cart,
             product: product1,
             meal_plan: meal_plan1)

      user2_cart = user2.shopping_cart
      create(:shopping_cart_item,
             shopping_cart: user2_cart,
             product: product2,
             meal_plan: meal_plan2)
    end

    it 'maintains separate shopping carts for different users' do
      # Simulate user1 viewing their cart
      allow(Current).to receive(:user).and_return(user1)
      user1_cart_items = user1.shopping_cart.group_and_sum_by_cart_items
      expect(user1_cart_items.count).to eq(1)
      expect(user1_cart_items.first[:products].first[:product]).to eq(product1)

      # Simulate user2 viewing their cart
      allow(Current).to receive(:user).and_return(user2)
      user2_cart_items = user2.shopping_cart.group_and_sum_by_cart_items
      expect(user2_cart_items.count).to eq(1)
      expect(user2_cart_items.first[:products].first[:product]).to eq(product2)

      # User1's cart should still be intact
      allow(Current).to receive(:user).and_return(user1)
      user1_cart_items_after = user1.shopping_cart.group_and_sum_by_cart_items
      expect(user1_cart_items_after.count).to eq(1)
      expect(user1_cart_items_after.first[:products].first[:product]).to eq(product1)
    end

    it 'prevents cross-user interference when new diet plans are created' do
      # Verify initial state
      allow(Current).to receive(:user).and_return(user1)
      expect(user1.shopping_cart.group_and_sum_by_cart_items.count).to eq(1)

      # Simulate another user creating a new diet plan
      other_user = create(:user)
      other_diet = create(:diet, user: other_user)
      other_diet_set = create(:diet_set, diet: other_diet)
      create(:diet_set_plan,
             diet_set: other_diet_set,
             date: Date.current,
             created_at: Time.current)

      # User1's cart should remain unchanged
      allow(Current).to receive(:user).and_return(user1)
      expect(user1.shopping_cart.group_and_sum_by_cart_items.count).to eq(1)
      expect(user1.shopping_cart.group_and_sum_by_cart_items.first[:products].first[:product]).to eq(product1)
    end
  end
end
