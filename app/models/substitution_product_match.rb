# frozen_string_literal: true

class SubstitutionProductMatch < ApplicationRecord
  belongs_to :user

  validates :source_product, :matched_product_name, presence: true
  validates :matched_product_name, uniqueness: { scope: [:user_id, :source_product] }

  normalizes :source_product, with: ->(value) { value.to_s.strip.presence }
  normalizes :matched_product_name, with: ->(value) { value.to_s.strip.presence }
end
