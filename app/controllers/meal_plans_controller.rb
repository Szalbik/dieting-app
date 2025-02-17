# frozen_string_literal: true

class MealPlansController < ApplicationController
  before_action :set_meal_plan, only: [:show, :toggle_shopping_bag]

  def toggle_shopping_bag
    @meal = Meal.find(params[:id])
    @meal.update(selected_for_cart: !@meal.selected_for_cart)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to meal_plans_path(date: date) }
    end
  end

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
    products = meal_plan.diet_set.meals.includes(:products).flat_map(&:products)
    products.each do |product|
      # Use product.id to uniquely identify the product
      cart_item = Current.user.shopping_cart.shopping_cart_items.find_by(product_id: product.id, date: date)
      if cart_item
        cart_item.increment!(:quantity)
      else
        cart.shopping_cart_items.create!(product: product, quantity: 1, date: date)
      end
    end
  end
end
