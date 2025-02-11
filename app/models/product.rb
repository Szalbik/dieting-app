# frozen_string_literal: true

class Product < ApplicationRecord
  belongs_to :diet_set, optional: true
  belongs_to :unit, optional: true
  has_many :ingredient_measures, dependent: :destroy
  has_one :product_category
  has_one :category, through: :product_category
  belongs_to :meal
  belongs_to :associated_product, class_name: 'Product', foreign_key: 'associated_product_id', optional: true

  def self.group_and_sum_by_name_and_unit(scope = Product)
    # Eager load ingredient measures
    # products_with_measures = scope.includes(:ingredient_measures, :category)

    # Group products by name
    grouped_by_name = scope.group_by(&:name)

    # Initialize a hash to store the summed products
    summed_products = {}

    grouped_by_name.each do |name, products|
      summed_products[name] ||= { measurements: [], category: 'Inne' }

      # Initialize a hash to store the summed amounts for each unit
      unit_hash = {}

      products.each do |product|
        # Fetch ingredient measurements for the product
        ingredient_measurements = product.ingredient_measures

        # Sum the amounts by unit for this product
        ingredient_measurements.each do |measurement|
          unit = measurement.unit || 'No Unit'
          amount = measurement.amount || 0
          unit_hash[unit] ||= 0
          unit_hash[unit] += amount
        end

        summed_products[name][:category] = product.category.name if product.category.present?
      end

      unit_hash.each do |unit, amount|
        summed_products[name][:measurements] << { unit: unit, amount: amount }
      end
    end

    # sort by category in desc order
    summed_products.sort_by { |k, v| v[:category] }.reverse
  end

  def self.group_and_sum_by_category(scope = Product)
    # Eager load ingredient measures and category
    products_with_measures = scope.includes(:ingredient_measures, :category)

    # Group products by category
    grouped_by_category = products_with_measures.group_by { |product| product.category.try(:name) || 'Inne' }

    # Initialize a hash to store the summed products
    summed_products = {}

    grouped_by_category.each do |category, products|
      summed_products[category] ||= { measurements: [] }

      # Initialize a hash to store the summed amounts for each unit
      unit_hash = {}

      products.each do |product|
        # Fetch ingredient measurements for the product
        ingredient_measurements = product.ingredient_measures

        # Sum the amounts by unit for this product
        ingredient_measurements.each do |measurement|
          unit = measurement.unit || 'No Unit'
          amount = measurement.amount || 0
          unit_hash[unit] ||= 0
          unit_hash[unit] += amount
        end
      end

      unit_hash.each do |unit, amount|
        summed_products[category][:measurements] << { unit: unit, amount: amount }
      end
    end

    summed_products
  end

  def self.group_and_sum_by_name_then_category(scope = Product)
    # Eager load ingredient measures and category
    # products_with_measures = scope.includes(:ingredient_measures, :category)

    # Group products by name
    grouped_by_name = scope.group_by(&:name)

    # Initialize a hash to store the summed products
    summed_products = {}

    grouped_by_name.each do |name, products|
      summed_products[name] ||= { measurements: [], category: 'Inne', name: name }

      # Initialize a hash to store the summed amounts for each unit
      unit_hash = {}

      products.each do |product|
        # Fetch ingredient measurements for the product
        ingredient_measurements = product.ingredient_measures

        # Sum the amounts by unit for this product
        ingredient_measurements.each do |measurement|
          unit = measurement.unit || 'No Unit'
          amount = measurement.amount || 0
          unit_hash[unit] ||= 0
          unit_hash[unit] += amount
        end

        summed_products[name][:category] = product.category.name if product.category.present?
      end

      unit_hash.each do |unit, amount|
        summed_products[name][:measurements] << { unit: unit, amount: amount }
      end
    end

    # Now group the summed products by category
    grouped_by_category = summed_products.group_by { |_name, data| data[:category] || 'Inne' }

    # # Transform the hash to keep only the measurements
    grouped_by_category.transform_values do |products|
      products.flat_map { |_name, data| data }
    end
  end
end
