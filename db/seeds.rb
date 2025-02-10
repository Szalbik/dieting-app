# frozen_string_literal: true

# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)

password = 'foobar'
password_diegst = BCrypt::Password.create(password)
User.create(email_address: 'damian@example.com', first_name: 'Damian', password_digest: password_diegst,
            password: password, password_confirmation: password)
User.create(email_address: 'kasia@example.com', first_name: 'Kasia', password_digest: password_diegst,
            password: password, password_confirmation: password)
User.create(email_address: 'admin@example.com', first_name: 'Admin', password_digest: password_diegst,
            password: password, password_confirmation: password, admin: true)
Category.create(name: 'Warzywa')
Category.create(name: 'Owoce')
Category.create(name: 'Mięso i Ryby')
Category.create(name: 'Wędliny')
Category.create(name: 'Nabiał')
Category.create(name: 'Pieczywo')
Category.create(name: 'Przyprawy')
Category.create(name: 'Orzechy')
Category.create(name: 'Inne')
Category.create(name: 'Napoje')
Category.create(name: 'Przetwory')
Category.create(name: 'Produkty zbożowe')
Category.create(name: 'Produkty mrożone')
