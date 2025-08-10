# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ShoppingCart, type: :model do
  describe 'shopping cart isolation' do
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
    end

    it 'prevents cross-user shopping cart interference' do
      # Create shopping cart items for both users
      user1_cart = user1.shopping_cart
      user1_cart_item = create(:shopping_cart_item,
                               shopping_cart: user1_cart,
                               product: product1,
                               meal_plan: meal_plan1)

      user2_cart = user2.shopping_cart
      user2_cart_item = create(:shopping_cart_item,
                               shopping_cart: user2_cart,
                               product: product2,
                               meal_plan: meal_plan2)

      # Verify that users can only see their own cart items
      user1_result = user1_cart.group_and_sum_by_cart_items
      user2_result = user2_cart.group_and_sum_by_cart_items

      # Check that user1's result contains their product
      expect(user1_result.any? { |group| group[:products].any? { |p| p[:product].id == product1.id } }).to be true
      expect(user1_result.any? { |group| group[:products].any? { |p| p[:product].id == product2.id } }).to be false

      # Check that user2's result contains their product
      expect(user2_result.any? { |group| group[:products].any? { |p| p[:product].id == product2.id } }).to be true
      expect(user2_result.any? { |group| group[:products].any? { |p| p[:product].id == product1.id } }).to be false

      # Verify cart item counts
      expect(user1_cart.shopping_cart_items.count).to eq(1)
      expect(user2_cart.shopping_cart_items.count).to eq(1)
    end

    it 'properly scopes diet set plans to current user' do
      # Create a shopping cart item for user1
      user1_cart = user1.shopping_cart
      user1_cart_item = create(:shopping_cart_item,
                               shopping_cart: user1_cart,
                               product: product1,
                               meal_plan: meal_plan1)

      # Test the new scope method directly
      scoped_items = ShoppingCartItem.with_current_or_future_diet_set_plan_for_user(user1)
      expect(scoped_items).to include(user1_cart_item)

      # Test with user2 - should not include user1's items
      scoped_items_user2 = ShoppingCartItem.with_current_or_future_diet_set_plan_for_user(user2)
      expect(scoped_items_user2).not_to include(user1_cart_item)
    end

    it 'maintains cart items when other users create new diet plans' do
      # Setup initial state
      user1_cart = user1.shopping_cart
      user1_cart_item = create(:shopping_cart_item,
                               shopping_cart: user1_cart,
                               product: product1,
                               meal_plan: meal_plan1)

      # Verify initial state - check that the product exists in the result
      user1_result = user1_cart.group_and_sum_by_cart_items
      expect(user1_result.any? { |group| group[:products].any? { |p| p[:product].id == product1.id } }).to be true

      # Simulate another user creating multiple new diet plans
      5.times do |i|
        other_user = create(:user)
        other_diet = create(:diet, user: other_user)
        other_diet_set = create(:diet_set, diet: other_diet)
        create(:diet_set_plan,
               diet_set: other_diet_set,
               date: Date.current,
               created_at: Time.current + i.seconds)
      end

      # User1's cart should remain unchanged
      user1_cart.reload
      user1_result = user1_cart.group_and_sum_by_cart_items
      expect(user1_result.any? { |group| group[:products].any? { |p| p[:product].id == product1.id } }).to be true
      expect(user1_cart.shopping_cart_items.count).to eq(1)
    end
  end

  describe '#group_and_sum_by_cart_items' do
    let(:user) { create(:user) }
    let(:diet) { create(:diet, user: user) }
    let(:diet_set) { create(:diet_set, diet: diet) }
    let(:meal) { create(:meal, diet_set: diet_set) }
    let(:product) { create(:product, :with_category, meal: meal) }
    let(:meal_plan) { create(:meal_plan, meal: meal, selected_for_cart: true) }
    let(:shopping_cart) { user.shopping_cart }

    before do
      create(:diet_set_plan, diet_set: diet_set, date: Date.current, created_at: 1.day.ago)
    end

    it 'returns aggregated cart items for the current user only' do
      cart_item = create(:shopping_cart_item,
                         shopping_cart: shopping_cart,
                         product: product,
                         meal_plan: meal_plan)

      # Debug: Check the product category before processing
      puts "\n=== DEBUG INFO ==="
      puts "Product ID: #{product.id}"
      puts "Product name: #{product.name}"
      puts "Product category present?: #{product.category.present?}"
      puts "Product category: #{product.category.inspect}"
      puts "Product category name: #{product.category&.name}"
      puts "==================\n"

      result = shopping_cart.group_and_sum_by_cart_items

      # Debug: Check the result structure
      puts "\n=== RESULT DEBUG ==="
      result.each_with_index do |group, index|
        puts "Group #{index}: #{group[:category].name}"
        group[:products].each do |p|
          puts "  - #{p[:name]} (ID: #{p[:product].id})"
        end
      end
      puts "==================\n"

      # The method returns grouped data by category, so we need to check the structure
      expect(result).to be_an(Array)
      expect(result.first).to have_key(:category)
      expect(result.first).to have_key(:products)

      # Check that the product exists in the result
      product_found = result.any? do |group|
        group[:products].any? { |p| p[:product].id == product.id }
      end
      expect(product_found).to be true

      # Verify that products with categories don't default to 'Inne'
      product_group = result.find { |group| group[:products].any? { |p| p[:product].id == product.id } }
      expect(product_group[:category].name).not_to eq('Inne')
      expect(product_group[:category].name).to start_with('Test Category')
    end

    it 'filters out items where selected_for_cart is false' do
      # Create a meal plan that's not selected for cart
      unselected_meal_plan = create(:meal_plan, meal: meal, selected_for_cart: false)
      unselected_cart_item = create(:shopping_cart_item,
                                    shopping_cart: shopping_cart,
                                    product: product,
                                    meal_plan: unselected_meal_plan,
                                    quantity: 3)

      # Create a meal plan that is selected for cart
      selected_meal_plan = create(:meal_plan, meal: meal, selected_for_cart: true)
      selected_cart_item = create(:shopping_cart_item,
                                  shopping_cart: shopping_cart,
                                  product: product,
                                  meal_plan: selected_meal_plan,
                                  quantity: 1)

      result = shopping_cart.group_and_sum_by_cart_items

      # Check that the selected product exists in the result
      selected_product_found = result.any? do |group|
        group[:products].any? { |p| p[:product].id == product.id }
      end
      expect(selected_product_found).to be true

      # The method should only return items where selected_for_cart is true
      # Since only the selected cart item should be included, the quantity should be 1
      product_group = result.find { |group| group[:products].any? { |p| p[:product].id == product.id } }
      product_data = product_group[:products].find { |p| p[:product].id == product.id }
      expect(product_data[:quantity]).to eq(1)

      # Verify that products with categories don't default to 'Inne'
      expect(product_group[:category].name).not_to eq('Inne')
      expect(product_group[:category].name).to start_with('Test Category')
    end
  end
end
