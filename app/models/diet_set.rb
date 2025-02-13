# frozen_string_literal: true

class DietSet < ApplicationRecord
  belongs_to :diet
  has_many :meals, dependent: :destroy
  has_many :products, through: :meals
  has_many :meal_plans, dependent: :destroy

  validates :name, presence: true

  def derrivated_name_from_meal
    meal = meals.where('name LIKE ?', '%Obiad%').first
    meal ? meal.name[10..-1].strip : name
  end
end
