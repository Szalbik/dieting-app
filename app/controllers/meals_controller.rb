# frozen_string_literal: true

class MealsController < ApplicationController
  def create
    diet_set = owned_diet_sets.find(params[:meal][:diet_set_id])

    if params[:meal][:recipe_id].present?
      Current.user.recipes.find(params[:meal][:recipe_id]).to_meal!(diet_set)
    elsif params[:meal][:source_meal_id].present?
      # The source meal being copied FROM may live in any of the user's diets
      # (pdf/generated/manual) — only the destination diet_set must be manual.
      any_owned_meals.find(params[:meal][:source_meal_id]).copy_into(diet_set)
    else
      create_manual_meal(diet_set)
    end

    redirect_to diet_set_path(diet_set)
  end

  def destroy
    meal = owned_meals.find(params[:id])
    diet_set = meal.diet_set
    meal.destroy
    redirect_to diet_set_path(diet_set), notice: 'Posiłek usunięty.'
  end

  private

  # Only manual (self-authored) diets are editable — PDF and AI-generated
  # diets stay a pristine copy of what was parsed/generated.
  def owned_diet_sets
    DietSet.joins(:diet).where(diets: { user_id: Current.user.id, source: 'manual' })
  end

  def owned_meals
    Meal.joins(diet_set: :diet).where(diets: { user_id: Current.user.id, source: 'manual' })
  end

  def any_owned_meals
    Meal.joins(diet_set: :diet).where(diets: { user_id: Current.user.id })
  end

  def create_manual_meal(diet_set)
    new_meal = diet_set.meals.create!(meal_params)
    ingredients = params.dig(:meal, :ingredients_text).to_s.split("\n").map(&:strip).reject(&:blank?)
      .map { |line| Recipe.parse_ingredient_line(line) }

    ingredients.each do |ing|
      product = new_meal.products.create!(name: ing['name'])
      product.ingredient_measures.create!(amount: ing['amount'], unit: ing['unit'])
    end

    estimate_macros_if_blank(new_meal, ingredients)
    new_meal
  end

  def meal_params
    params.require(:meal).permit(:meal_type, :name, :instructions, :kcal, :protein, :fat, :carbs)
  end

  def estimate_macros_if_blank(meal, ingredients)
    return if meal.kcal.present? || ingredients.blank?

    macros = Chat::MealMacroEstimatorService.new(name: meal.name, ingredients: ingredients).call
    meal.update!(kcal: macros['kcal'], protein: macros['protein'], fat: macros['fat'], carbs: macros['carbs'])
  rescue StandardError => e
    Rails.logger.error("Macro estimation failed for meal: #{e.message}")
  end
end
