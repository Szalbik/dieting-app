# frozen_string_literal: true

class DietSet < ApplicationRecord
  belongs_to :diet
  has_many :products, dependent: :nullify
  has_many :meal_plans, dependent: :nullify

  validates :name, presence: true
end
