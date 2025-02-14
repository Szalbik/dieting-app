# frozen_string_literal: true

class MealPlansController < ApplicationController
  before_action :set_meal_plan, only: [:show]

  def show
    if Current.user.active_diets.empty?
      redirect_to new_diet_path, warning: 'You need to create a diet first.'
    end

    respond_to do |format|
      format.turbo_stream
      format.html
    end
  end

  def create
    diet_set = DietSet.find(meal_plan_params[:diet_set_id])
    @meal_plan = MealPlan.new(date: date, diet_set: diet_set, diet: diet_set.diet)

    if @meal_plan.save
      add_meal_plan_products_to_cart(@meal_plan)
      redirect_to meal_plans_path(date: date), notice: 'Meal plan was successfully updated.'
    else
      render :show
    end
  end

  private

  def set_meal_plan
    @meal_plan = Current.user.meal_plans.where(date: date).sort.last unless params['reassign'].present?
    @meal_plan ||= MealPlan.new(date: date)
  end

  def date
    @date = params['date'].present? ? Date.parse(params['date']).to_s : Date.current.to_s
  end

  def meal_plan_params
    params.require(:meal_plan).permit(:diet_set_id)
  end

  # This method will extract all products from the meal plan's diet set and add them to the shopping cart.
  def add_meal_plan_products_to_cart(meal_plan)
    cart = Current.user.shopping_cart
    cart.shopping_cart_items.where(product_id: meal_plan.diet_set.products.ids).destroy_all
    # Assuming your associations:
    # MealPlan belongs_to :diet_set
    # DietSet has_many :meals
    # Meal has_many :products
    products = meal_plan.diet_set.meals.includes(:products).flat_map(&:products)

    products.each do |product|
      # Check if the product is already in the cart.
      cart_item = cart.shopping_cart_items.find_by(product_id: product.id)
      if cart_item
        # Update the quantity (for example, increment by 1)
        cart_item.increment!(:quantity)
      else
        # Create a new cart item with a quantity of 1 (or calculate based on your logic)
        cart.shopping_cart_items.create!(product: product, quantity: 1)
      end
    end
  end
end
