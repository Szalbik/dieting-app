# frozen_string_literal: true

FactoryBot.define do
  factory(:meal) do
    name { Faker::Food.dish }
    instructions { Faker::Lorem.paragraph }
    diet_set
    meal_type { %w[breakfast lunch dinner snack].sample }
    kcal { rand(200..800) }
    protein { rand(10..40).to_f }
    fat { rand(5..30).to_f }
    carbs { rand(20..80).to_f }
  end
end
