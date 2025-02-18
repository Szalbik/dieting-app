# frozen_string_literal: true

class ShoppingCart < ApplicationRecord
  belongs_to :user
  has_many :shopping_cart_items, dependent: :destroy

  # Optional: helper to aggregate products (group, sum, etc.)
  def grouped_items
    # Load cart items along with the associated product, category, and ingredient_measures.
    items = shopping_cart_items.with_current_or_future_meal_plan.includes(product: [:category, :ingredient_measures])

    # Group by category (or “Inne” if nil)
    grouped_by_category = items.group_by { |item| item.product.category || OpenStruct.new(name: 'Inne') }

    grouped_by_category.map do |category, items|
      # Now group items by product name.
      grouped_by_product_name = items.group_by { |item| item.product.name }
      products = grouped_by_product_name.map do |product_name, cart_items|
        # Sum the quantity of all items for this product.
        total_quantity = cart_items.sum { |item| item.product.meal.selected_for_cart ? item.quantity : 0 }

        # Aggregate the ingredient measures across all items.
        # We use a hash keyed by the unit (or a composite key if needed) to sum amounts.
        aggregated_measures = {}
        cart_items.each do |item|
          item.product.ingredient_measures.each do |measure|
            key = measure.unit # adjust key if you need more granularity (e.g. ingredient name if available)
            aggregated_measures[key] ||= 0.0
            aggregated_measures[key] += measure.amount * item.quantity
          end
        end

        # Only include the product if there is a nonzero total quantity.
        if total_quantity > 0
          {
            product: cart_items.first.product,      # a representative product
            product_name: product_name,
            quantity: total_quantity,
            aggregated_ingredient_measures: aggregated_measures,
          }
        end
      end.compact

      { category: category, products: products } if products.any?
    end.compact
  end

  def group_and_sum_by_cart_items
    # Eager-load associated product, its ingredient_measures, and category.
    items = shopping_cart_items.with_current_or_future_meal_plan.includes(product: [:ingredient_measures, :category])

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

    groups.values
  end
end
