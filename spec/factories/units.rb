# frozen_string_literal: true

FactoryBot.define do
  factory(:unit) do
    name { %w[gram kilogram liter milliliter piece cup tablespoon teaspoon].sample }
  end
end
