# frozen_string_literal: true



FactoryBot.define do
  factory(:user) do
    password = Faker::Internet.password
    password_digest = BCrypt::Password.create(password)

    first_name { Faker::Name.first_name }

    email_address { Faker::Internet.email }
    password_digest { password_digest }
    password { password }
    password_confirmation { password }
  end
end
