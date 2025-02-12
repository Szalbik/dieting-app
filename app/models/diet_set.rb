# frozen_string_literal: true

class DietSet < ApplicationRecord
  belongs_to :diet
  has_many :products, dependent: :nullify
  has_many :meal_plans, dependent: :destroy
  has_many :meals, dependent: :destroy

  validates :name, presence: true
end
