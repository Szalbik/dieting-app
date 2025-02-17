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
end
