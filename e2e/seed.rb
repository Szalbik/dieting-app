# frozen_string_literal: true

# Idempotent dev-DB fixture for the offline e2e: one throwaway user, one manual
# diet, plans for today..+3, a freshly synced shopping list with nothing bought,
# no own items, nothing eaten. Run before and after the suite; touches only this user.
#   bin/rails runner e2e/seed.rb
# ponytail: resets instead of deleting — User#destroy trips FKs in this schema.
EMAIL = 'offline-e2e@example.com'
PASSWORD = 'offline-e2e-123'

user = User.find_or_create_by!(email_address: EMAIL) do |u|
  u.password = u.password_confirmation = PASSWORD
  u.first_name = 'E2E'
end

diet = user.diets.find_or_create_by!(name: 'Dieta offline') do |d|
  d.source = 'manual'
  d.status = 'ready'
  d.active = true
end
day = diet.diet_sets.first || diet.diet_sets.create!(name: 'Dzień 1')
if day.meals.empty?
  { 'Owsianka' => ['Płatki owsiane', 'Mleko 2%', 'Banan'], 'Kanapki' => ['Chleb żytni', 'Ser żółty', 'Pomidor'] }.each do |meal_name, products|
    meal = day.meals.create!(name: meal_name, meal_type: 'breakfast', kcal: 400, protein: 20, fat: 10, carbs: 50)
    products.each { |name| meal.products.create!(name: name, diet_set: day) }
  end
end

(Date.current..(Date.current + 3)).each do |date|
  plan = DietSetPlan.find_or_create_by!(date: date, diet: diet, diet_set: day)
  day.meals.each { |meal| plan.meal_plans.find_or_create_by!(meal: meal) }
end
DietSetPlan.where(diet: diet).update_all(servings: 1, shopping_done: false)
MealPlan.joins(:diet_set_plan).where(diet_set_plans: { diet_id: diet.id }).update_all(eaten: false, selected_for_cart: true)

cart = user.shopping_cart
cart.custom_cart_items.delete_all
ShoppingCartItem.with_deleted.where(shopping_cart: cart).delete_all # sync recreates them unbought
ShoppingCartSyncService.new(shopping_cart: cart, users: cart.member_users).call
puts "#{EMAIL} / #{PASSWORD}: #{cart.shopping_cart_items.count} cart items"
