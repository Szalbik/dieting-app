# frozen_string_literal: true

class ShoppingListsController < ApplicationController
  def index
    # Fetch meal plans with meal_date on or after today
    meal_plans = Current.user.meal_plans.where('date >= ?', Date.current)
      .includes(diet_set: { meals: :products })

    # Collect all products from the meal plans (using the associations)
    products = meal_plans.flat_map(&:products)

    # Group and sum products by name then category using your custom method.
    @grouped_products = Product.group_and_sum_by_name_then_category(products)
  end

  def remove_item
    product_id = params[:product_id]
    session[:removed_shopping_list_items] ||= []
    unless session[:removed_shopping_list_items].include?(product_id)
      session[:removed_shopping_list_items] << product_id
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove("product-#{product_id}")
      end
      format.html { redirect_to shopping_lists_path }
    end
  end
end
