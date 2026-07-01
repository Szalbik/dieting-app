# frozen_string_literal: true

class ShoppingCart < ApplicationRecord
  belongs_to :user
  has_many :shopping_cart_items, dependent: :destroy
  has_many :custom_cart_items, dependent: :destroy
  has_many :active_users, class_name: 'User', foreign_key: :active_shopping_cart_id, inverse_of: :active_shopping_cart

  # Diets actually driving the current cart (via the selected diet_set_plans),
  # not whatever Diet carries the `active:` flag.
  def diets_in_cart
    diet_ids = ShoppingCartItem
      .with_current_or_future_diet_set_plan_for_users(member_users)
      .where(shopping_cart: self)
      .joins(meal_plan: :diet_set_plan)
      .where(meal_plans: { selected_for_cart: true })
      .distinct
      .pluck('diet_set_plans.diet_id')
    Diet.where(id: diet_ids)
  end

  # How many day-plans of `diet` are actually feeding the current cart,
  # as opposed to Diet#diet_sets.count (every day-template the diet defines,
  # whether or not it's scheduled).
  def diet_set_plans_count_in_cart(diet)
    ShoppingCartItem
      .with_current_or_future_diet_set_plan_for_users(member_users)
      .where(shopping_cart: self)
      .joins(meal_plan: :diet_set_plan)
      .where(meal_plans: { selected_for_cart: true }, diet_set_plans: { diet_id: diet.id })
      .distinct
      .count('diet_set_plans.id')
  end

  def group_and_sum_by_cart_items
    # Eager-load associated product, its ingredient_measures, and category.
    # Use the new method that properly scopes to the current user
    items = ShoppingCartItem.with_current_or_future_diet_set_plan_for_users(member_users)
      .where(shopping_cart: self)
      .joins(:meal_plan)
      .where(meal_plans: { selected_for_cart: true })
      .includes(product: [:ingredient_measures, :category, :canonical_product])

    summed_products = {}

    items.group_by { |item| item.product.shopping_cart_group_key }.each_value do |grouped_items|
      display_name = Product.best_shopping_list_display_name(grouped_items.map(&:product))
      summed_products[display_name] ||= {
        product: nil,
        name: display_name,
        quantity: 0,
        aggregated_ingredient_measures: [],
        category: nil,
        bought: true,
      }

      unit_hash = {}

      grouped_items.each do |item|
        product = item.product
        summed_products[display_name][:quantity] += item.quantity
        summed_products[display_name][:product] ||= product
        summed_products[display_name][:bought] &&= item.bought

        summed_products[display_name][:category] = product.category if product.category.present?

        product.ingredient_measures.each do |measurement|
          raw_unit = measurement.unit || ''
          normalized_unit = raw_unit.singularize(:pl)
          unit_hash[normalized_unit] ||= 0.0
          unit_hash[normalized_unit] += measurement.amount.to_f * item.quantity.to_i
        end
      end

      aggregated = unit_hash.map { |unit, amount| { unit: unit, amount: amount } }
      summed_products[display_name][:aggregated_ingredient_measures] = aggregated
    end

    # Now, group the aggregated products by category.
    groups = {}
    summed_products.each do |_name, data|
      category_obj = data[:category] || OpenStruct.new(name: 'Inne')
      groups[category_obj.name] ||= { category: category_obj, products: [] }
      groups[category_obj.name][:products] << data
    end

    order_hash = {
      'Pieczywo' => 1,
      'Owoce' => 2,
      'Warzywa' => 3,
      'Przyprawy' => 4,
      'Nabiał' => 5,
      'Wędliny' => 6,
      'Mięso i Ryby' => 7,
      'Produkty zbożowe' => 8,
      'Przetwory' => 9,
      'Inne' => 10,
      'Napoje' => 11,
    }

    groups.values.sort_by do |group|
      order_hash[group[:category].name] || Float::INFINITY
    end
  end

  def member_users
    active_users.presence || [user]
  end

  def shared?
    member_users.many?
  end

  def member_labels
    member_users.map { |member| member.first_name.presence || member.email_address }
  end

  def broadcast_contents
    broadcast_action_later_to(
      self,
      action: :replace,
      target: 'shopping_cart',
      partial: 'shopping_carts/shopping_cart',
      locals: { shopping_cart: self },
      attributes: { method: :morph }
    )
  end
end
