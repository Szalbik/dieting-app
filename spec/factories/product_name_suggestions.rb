# frozen_string_literal: true

FactoryBot.define do
  factory :product_name_suggestion do
    user
    sequence(:raw_name) { |n| "Raw Product #{n}" }
    canonical_product
    confidence    { 0.91 }
    match_type    { "fuzzy" }
    source        { "manual" }
    status        { "pending" }
    occurrence_count { 1 }
  end
end
