# frozen_string_literal: true

FactoryBot.define do
  factory(:canonical_product) do
    user
    sequence(:name) { |n| "Canonical Product #{n}" }
  end
end
