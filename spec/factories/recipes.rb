# frozen_string_literal: true

FactoryBot.define do
  factory(:recipe) do
    user
    name { Faker::Food.dish }
    meal_type { 'lunch' }
    instructions { Faker::Lorem.paragraph }
    kcal { rand(200..800) }
    protein { rand(10..40).to_f }
    fat { rand(5..30).to_f }
    carbs { rand(20..80).to_f }
    ingredients { [{ 'name' => 'Kurczak', 'amount' => 200.0, 'unit' => 'g' }] }
  end
end
