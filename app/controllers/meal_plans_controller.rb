# frozen_string_literal: true

class MealPlansController < ApplicationController
  def show
    @meal_plan = Current.user.meal_plans.find_or_initialize_by(date: Date.current)
  end

  def create
    diet_set = DietSet.find(meal_plan_params[:diet_set_id])
    @meal_plan = Current.user.meal_plans.build(date: Date.current, diet_set: diet_set, diet: diet_set.diet)

    if @meal_plan.save
      redirect_to meal_plans_path, notice: 'Meal plan was successfully updated.'
    else
      render :show
    end
  end

  private

  def meal_plan_params
    params.require(:meal_plan).permit(:diet_set_id)
  end
end
