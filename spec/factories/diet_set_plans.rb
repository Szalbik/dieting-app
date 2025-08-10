# frozen_string_literal: true

FactoryBot.define do
  factory(:diet_set_plan) do
    diet_set
    diet { diet_set.diet }
    date { Date.current }
    created_at { 1.day.ago }
  end
end
