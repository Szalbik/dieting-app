# frozen_string_literal: true

class RecipesController < ApplicationController
  def index
    @recipes = Current.user.recipes.order(:name)
  end

  def new
    @recipe = Recipe.new
  end

  def create
    @recipe = Current.user.recipes.new(recipe_params)
    @recipe.ingredients = parse_ingredients(params.dig(:recipe, :ingredients_text))
    estimate_macros_if_blank(@recipe)

    if @recipe.save
      redirect_to recipes_path, notice: 'Przepis zapisany.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @recipe = Current.user.recipes.find(params[:id])
  end

  def update
    @recipe = Current.user.recipes.find(params[:id])
    @recipe.assign_attributes(recipe_params)
    @recipe.ingredients = parse_ingredients(params.dig(:recipe, :ingredients_text))
    estimate_macros_if_blank(@recipe)

    if @recipe.save
      redirect_to recipes_path, notice: 'Przepis zaktualizowany.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    Current.user.recipes.find(params[:id]).destroy
    redirect_to recipes_path, notice: 'Przepis usunięty.'
  end

  private

  def recipe_params
    params.require(:recipe).permit(:name, :meal_type, :instructions, :kcal, :protein, :fat, :carbs)
  end

  def parse_ingredients(text)
    text.to_s.split("\n").map(&:strip).reject(&:blank?).map { |line| Recipe.parse_ingredient_line(line) }
  end

  def estimate_macros_if_blank(recipe)
    return if recipe.kcal.present? || recipe.ingredients.blank?

    macros = Chat::MealMacroEstimatorService.new(name: recipe.name, ingredients: recipe.ingredients).call
    recipe.kcal = macros['kcal']
    recipe.protein = macros['protein']
    recipe.fat = macros['fat']
    recipe.carbs = macros['carbs']
  rescue StandardError => e
    Rails.logger.error("Macro estimation failed for recipe: #{e.message}")
  end
end
