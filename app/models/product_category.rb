# frozen_string_literal: true

class ProductCategory < ApplicationRecord
  belongs_to :product
  belongs_to :category

  # Updates the state to true for all product categories whose associated product's name
  # matches the given pattern. Optionally, if a new category name is provided, it sets the
  # category to that (creating it if necessary).
  #
  # @param pattern [String] the pattern to match against products.name using SQL LIKE.
  # @param new_category_name [String, nil] optional new category name to assign.
  # @return [Integer] the number of records updated.
  def self.confirm_state_for(pattern, new_category_name = nil)
    scope = joins(:product).where('products.name LIKE ?', "%#{pattern}%")

    if new_category_name.present?
      category = Category.find_or_create_by!(name: new_category_name)
      affected_count = scope.update_all(state: true, category_id: category.id)
      puts "Updated #{affected_count} product category record(s) to state true and set category to '#{new_category_name}' for products matching '%#{pattern}%'."
    else
      affected_count = scope.update_all(state: true)
      puts "Updated #{affected_count} product category record(s) to state true for products matching '%#{pattern}%'."
    end

    affected_count
  end
end
