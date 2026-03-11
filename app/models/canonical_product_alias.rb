# frozen_string_literal: true

class CanonicalProductAlias < ApplicationRecord
  belongs_to :canonical_product

  validates :name, :normalized_name, :stem_signature, presence: true
  validates :name, uniqueness: { scope: :canonical_product_id }

  before_validation :normalize_fields

  private

  def normalize_fields
    cleaned = ProductSubstitution.strip_quantity_from_name(name).to_s.strip
    self.name = cleaned.presence
    self.normalized_name = ProductSubstitution.normalize_name(cleaned)
    self.stem_signature = cleaned
      .then { |value| ProductSubstitution.normalize_name(value) }
      .split
      .map { |token| ProductSubstitution.normalize_polish_stem(token) }
      .reject(&:blank?)
      .sort
      .join(' ')
  end
end
