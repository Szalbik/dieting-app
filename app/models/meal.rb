# frozen_string_literal: true

class Meal < ApplicationRecord
  belongs_to :diet_set
  has_many :products, dependent: :destroy
end
