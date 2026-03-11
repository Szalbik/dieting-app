# frozen_string_literal: true

FactoryBot.define do
  factory(:product_substitution) do
    user
    source_product { 'tunczyk' }
    replacement_product { 'losos' }
  end
end
