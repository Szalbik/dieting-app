# frozen_string_literal: true

class CanonicalProduct < ApplicationRecord
  belongs_to :user

  has_many :canonical_product_aliases, dependent: :destroy
  has_many :products, dependent: :nullify
  has_many :base_products, class_name: 'Product', foreign_key: :base_canonical_product_id, inverse_of: :base_canonical_product, dependent: :nullify
  has_many :source_product_substitutions, class_name: 'ProductSubstitution', foreign_key: :source_canonical_product_id, inverse_of: :source_canonical_product, dependent: :nullify
  has_many :replacement_product_substitutions, class_name: 'ProductSubstitution', foreign_key: :replacement_canonical_product_id, inverse_of: :replacement_canonical_product, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :user_id }

  before_validation :normalize_name
  after_commit :ensure_self_alias!, on: [:create, :update]

  private

  def normalize_name
    self.name = name.to_s.strip.presence
  end

  def ensure_self_alias!
    canonical_product_aliases.find_or_create_by!(name: name)
  end
end
