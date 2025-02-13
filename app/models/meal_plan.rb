# frozen_string_literal: true

class MealPlan < ApplicationRecord
  belongs_to :diet
  belongs_to :diet_set

  # Assuming your DietSet model already has:
  #   has_many :meals
  has_many :meals, through: :diet_set

  # And your Meal model has:
  #   has_many :products
  has_many :products, through: :meals
end
