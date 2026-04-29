# frozen_string_literal: true

class ProductNameSuggestion < ApplicationRecord
  STATUSES    = %w[pending approved rejected].freeze
  MATCH_TYPES = %w[exact_normalized exact_name stem fuzzy new].freeze
  SOURCES     = %w[import manual].freeze

  belongs_to :user
  belongs_to :canonical_product, optional: true

  validates :raw_name,   presence: true
  validates :match_type, inclusion: { in: MATCH_TYPES }
  validates :source,     inclusion: { in: SOURCES }
  validates :status,     inclusion: { in: STATUSES }
  validates :confidence, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }

  scope :pending,  -> { where(status: 'pending') }
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }

  def self.record_suggestion!(user:, raw_name:, canonical_product:, confidence:, match_type:, source:)
    existing = where(user: user, raw_name: raw_name, status: 'pending').first

    if existing
      existing.increment!(:occurrence_count)
    else
      create!(
        user: user,
        raw_name: raw_name,
        canonical_product: canonical_product,
        confidence: confidence,
        match_type: match_type.to_s,
        source: source.to_s,
        status: 'pending',
        occurrence_count: 1
      )
    end
  end
end
