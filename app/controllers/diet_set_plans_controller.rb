# frozen_string_literal: true

class DietSetPlansController < ApplicationController
  before_action :set_diet_set_plan, only: [:show, :toggle_shopping_bag]

  def toggle_shopping_bag
    @meal_plan = MealPlan.find(params[:id])
    @meal_plan.update(selected_for_cart: !@meal_plan.selected_for_cart)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to diet_set_plans_path(date: date) }
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
    diet_set = DietSet.find(diet_set_plan_params[:diet_set_id])
    @diet_set_plan = DietSetPlan.new(date: date, diet_set: diet_set, diet: diet_set.diet)

    if @diet_set_plan.save
      # Create associated meal_plan records for each meal in the diet_set.
      diet_set.meals.each do |meal|
        @diet_set_plan.meal_plans.create!(meal: meal)
      end
      add_diet_set_plan_products_to_cart(@diet_set_plan)
      redirect_to diet_set_plans_path(date: date), notice: 'Meal plan was successfully updated.'
    else
      render :show
    end
  end

  def swap
    current_date = Date.parse(params[:current_date])
    target_date = Date.parse(params[:target_date])

    # Find diet set plans for both dates
    current_plan = Current.user.diet_set_plans.where(date: current_date).first
    target_plan = Current.user.diet_set_plans.where(date: target_date).first

    if current_plan && target_plan
      # Use a transaction to ensure both updates succeed or fail together
      ActiveRecord::Base.transaction do
        # Temporarily use a different date to avoid conflicts
        temp_date = Date.new(1900, 1, 1)

        # Move current plan to temp date first
        current_plan.update!(date: temp_date)

        # Move target plan to current date
        target_plan.update!(date: current_date)

        # Move current plan (now at temp date) to target date
        current_plan.update!(date: target_date)
      end

      render json: { success: true, message: 'Zestawy diety zostały zamienione pomyślnie.' }
    else
      render json: { success: false, message: 'Nie można znaleźć planów diety dla wybranych dat.' }, status: :unprocessable_entity
    end
  rescue Date::Error => e
    render json: { success: false, message: 'Nieprawidłowy format daty.' }, status: :bad_request
  rescue StandardError => e
    render json: { success: false, message: 'Wystąpił błąd podczas zamiany zestawów diety.' }, status: :internal_server_error
  end

  private

  def set_diet_set_plan
    @diet_set_plan = Current.user.diet_set_plans.where(date: date).sort.last unless params['reassign'].present?
    @diet_set_plan ||= DietSetPlan.new(date: date)
  end

  def date
    @date = params['date'].present? ? Date.parse(params['date']).to_s : Date.current.to_s
  end

  def diet_set_plan_params
    params.require(:diet_set_plan).permit(:diet_set_id)
  end

  def shopping_cart
    @shopping_cart ||= Current.user.shopping_cart
  end

  def add_diet_set_plan_products_to_cart(diet_set_plan)
    # Iterate over each meal_plan in the given diet_set_plan.
    diet_set_plan.meal_plans.includes(meal: :products).each do |meal_plan|
      # Only process products for meal_plans that are selected for cart.
      next unless meal_plan.selected_for_cart

      # For each product in the meal associated with this meal_plan...
      meal_plan.products.each do |product|
        # Find a shopping cart item that already has this product, date, and meal_plan.
        cart_item = shopping_cart.shopping_cart_items.find_by(
          product_id: product.id,
          date: date,
          meal_plan_id: meal_plan.id)
        if cart_item
          cart_item.increment!(:quantity)
        else
          Current.user.shopping_cart.shopping_cart_items.create!(
            product: product,
            quantity: 1,
            date: date,
            meal_plan: meal_plan
          )
        end
      end
    end
  end
end
