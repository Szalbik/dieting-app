# frozen_string_literal: true

FactoryBot.define do
  factory :dietitian_waitlist_entry do
    first_name { Faker::Name.first_name }
    email_address { Faker::Internet.unique.email }
    company_name { "#{Faker::Company.name} Clinic" }
    status { :pending }
    notes { nil }
    demo_called_at { nil }
    approved_at { nil }
  end
end
