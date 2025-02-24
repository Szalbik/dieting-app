# frozen_string_literal: true

class ShoppingCart < ApplicationRecord
  belongs_to :user
  has_many :shopping_cart_items, dependent: :destroy

  def group_and_sum_by_cart_items
    # Eager-load associated product, its ingredient_measures, and category.
    items = shopping_cart_items.with_current_or_future_diet_set_plan.includes(product: [:ingredient_measures, :category])

    # Filter items to include only those with diet_set_plan.selected_for_cart true.
    items = items.select { |item| item.selected_for_cart }

    # Group shopping cart items by product name.
    grouped_by_name = items.group_by { |item| item.product.name }

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

        # Store product category (defaulting to 'Inne' if none exists).
        if product.category.present?
          summed_products[name][:category] = product.category
        else
          summed_products[name][:category] ||= OpenStruct.new(name: 'Inne')
        end

        product.ingredient_measures.each do |measurement|
          raw_unit = measurement.unit || ''
          normalized_unit = raw_unit.singularize(:pl)
          unit_hash[normalized_unit] ||= 0.0
          # Multiply the measurement amount by the item's quantity.
          unit_hash[normalized_unit] += measurement.amount * item.quantity
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
end
