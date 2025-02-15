# frozen_string_literal: true

FactoryBot.define do
  factory(:diet) do
    name { "Diet for #{Faker::Name.first_name}" }
    user

    trait :with_pdf do
      after(:create) do |diet|
        diet.pdf.attach(io: File.open(Rails.root.join('spec/fixtures/files/diet_for_one_week.pdf')),
                        filename: 'diet_for_one_week.pdf')
      end
    end

    trait :with_long_pdf do
      after(:create) do |diet|
        diet.pdf.attach(io: File.open(Rails.root.join('spec/fixtures/files/diet_for_two_weeks.pdf')),
                        filename: 'diet_for_two_weeks.pdf')
      end
    end
  end
end
