# frozen_string_literal: true

class Meal < ApplicationRecord
  belongs_to :diet_set
  has_many :products, dependent: :nullify
  has_many :meal_plans, dependent: :destroy
end
