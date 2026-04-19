# frozen_string_literal: true

class CanonicalProductAlias < ApplicationRecord
  belongs_to :canonical_product

  validates :name, :normalized_name, :stem_signature, presence: true
  validates :name, uniqueness: { scope: :canonical_product_id }

  before_validation :normalize_fields

  private

  def normalize_fields
    normalizer = ShoppingList::ProductNormalizer.new
    cleaned = normalizer.cleaned_name(name)
    self.name = cleaned.presence
    self.normalized_name = ProductSubstitution.normalize_name(cleaned)
    self.stem_signature = normalizer.call(raw_name: cleaned)[:key]
  end
end
