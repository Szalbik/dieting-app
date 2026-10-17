# frozen_string_literal: true

# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)

# Demo accounts with a public password: never in production (the entrypoint runs
# db:prepare, which seeds a fresh database).
unless Rails.env.production?
  password = 'foobar'
  password_diegst = BCrypt::Password.create(password)
  User.create(email_address: 'damian@example.com', first_name: 'Damian', password_digest: password_diegst,
              password: password, password_confirmation: password)
  User.create(email_address: 'kasia@example.com', first_name: 'Kasia', password_digest: password_diegst,
              password: password, password_confirmation: password)
  User.create(email_address: 'admin@example.com', first_name: 'Admin', password_digest: password_diegst,
              password: password, password_confirmation: password, admin: true)
end
Category.find_or_create_by(name: 'Warzywa')
Category.find_or_create_by(name: 'Owoce')
Category.find_or_create_by(name: 'Mięso i Ryby')
Category.find_or_create_by(name: 'Wędliny')
Category.find_or_create_by(name: 'Nabiał')
Category.find_or_create_by(name: 'Pieczywo')
Category.find_or_create_by(name: 'Przyprawy')
Category.find_or_create_by(name: 'Orzechy')
Category.find_or_create_by(name: 'Inne')
Category.find_or_create_by(name: 'Napoje')
Category.find_or_create_by(name: 'Przetwory')
Category.find_or_create_by(name: 'Produkty zbożowe')
Category.find_or_create_by(name: 'Produkty mrożone')
Category.find_or_create_by(name: 'Tłuszcze i oleje')
Category.find_or_create_by(name: 'Słodycze i przekąski')
