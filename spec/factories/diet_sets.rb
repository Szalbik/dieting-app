# frozen_string_literal: true

FactoryBot.define do
  factory(:diet_set) do
    diet
    name { "Diet Set #{Faker::Lorem.word}" }
  end
end
