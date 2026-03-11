# frozen_string_literal: true

FactoryBot.define do
  factory(:substitution_product_match) do
    user
    source_product { 'Jogurt naturalny' }
    matched_product_name { 'Jogurt naturalny 2% tluszczu' }
    confidence { 0.9 }
  end
end
