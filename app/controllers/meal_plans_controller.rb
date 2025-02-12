# frozen_string_literal: true

class MealPlansController < ApplicationController
  before_action :set_meal_plan, only: [:show]

  def show
    if Current.user.active_diets.empty?
      redirect_to new_diet_path, alert: 'You need to create a diet first.'
    end
  end

  def create
    diet_set = DietSet.find(meal_plan_params[:diet_set_id])
    @meal_plan = MealPlan.new(date: date, diet_set: diet_set, diet: diet_set.diet)

    if @meal_plan.save
      redirect_to meal_plans_path(date: date), notice: 'Meal plan was successfully updated.'
    else
      render :show
    end
  end

  private

  def set_meal_plan
    @meal_plan = Current.user.meal_plans.find_by(date: date)
    @meal_plan ||= MealPlan.new(date: date)
  end

  def date
    params['date'].present? ? Date.parse(params['date']).to_s : Date.current.to_s
  end

  def meal_plan_params
    params.require(:meal_plan).permit(:diet_set_id)
  end
end
