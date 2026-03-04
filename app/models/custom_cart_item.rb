# frozen_string_literal: true

class CustomCartItem < ApplicationRecord
  belongs_to :shopping_cart

  validates :name, presence: true, length: { maximum: 255 }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :unit, length: { maximum: 50 }, allow_blank: true

  normalizes :name, with: ->(n) { n.to_s.strip.presence }
  normalizes :unit, with: ->(u) { u.to_s.strip.presence || 'szt' }
end
