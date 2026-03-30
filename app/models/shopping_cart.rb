# frozen_string_literal: true

class ShoppingCart < ApplicationRecord
  belongs_to :user
  has_many :shopping_cart_items, dependent: :destroy
  has_many :custom_cart_items, dependent: :destroy
  has_many :active_users, class_name: 'User', foreign_key: :active_shopping_cart_id, inverse_of: :active_shopping_cart

  def group_and_sum_by_cart_items
    # Eager-load associated product, its ingredient_measures, and category.
    # Use the new method that properly scopes to the current user
    items = ShoppingCartItem.with_current_or_future_diet_set_plan_for_users(member_users)
      .where(shopping_cart: self)
      .joins(:meal_plan)
      .where(meal_plans: { selected_for_cart: true })
      .includes(product: [:ingredient_measures, :category, :canonical_product])

    # Jedna linia na „nazwę sklepową”: CanonicalProduct (jeśli jest), inaczej nazwa bez ilości, inaczej raw name.
    grouped_by_name = items.group_by { |item| item.product.shopping_cart_group_name }

    # Build a hash to hold aggregated product data.
    summed_products = {}

    grouped_by_name.each do |name, items|
      summed_products[name] ||= {
        product: nil,
        name: name,
        quantity: 0,
        aggregated_ingredient_measures: [],
        category: nil,
      }

      # Use a hash to accumulate totals for each unit.
      unit_hash = {}

      items.each do |item|
        product = item.product
        summed_products[name][:quantity] += item.quantity
        # Use the first encountered product as the representative.
        summed_products[name][:product] ||= product

        # Prefer any real category in the group; do not overwrite with "Inne" when a
        # later line has no category (common after grouping by canonical name).
        summed_products[name][:category] = product.category if product.category.present?

        product.ingredient_measures.each do |measurement|
          raw_unit = measurement.unit || ''
          normalized_unit = raw_unit.singularize(:pl)
          unit_hash[normalized_unit] ||= 0.0
          # Multiply the measurement amount by the item's quantity, ensuring nil safety.
          unit_hash[normalized_unit] += measurement.amount.to_f * item.quantity.to_i
        end
      end

      # Convert the accumulated unit totals into an array.
      aggregated = unit_hash.map { |unit, amount| { unit: unit, amount: amount } }
      summed_products[name][:aggregated_ingredient_measures] = aggregated
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
