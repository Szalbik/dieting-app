# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.3.5'

gem 'rails', '~> 8.0.1'

# Asssets pipeline
gem 'cssbundling-rails' # Bundle and process CSS [https://github.com/rails/cssbundling-rails]
gem 'jsbundling-rails' # Bundle and transpile JavaScript [https://github.com/rails/jsbundling-rails]
gem 'propshaft' 

# Monitoring
gem 'honeybadger', '~> 5.4'
gem 'rails_performance'
# gem 'lograge'
# gem 'bullet'
# gem 'rack-mini-profiler'
# gem 'pg_hero'

gem 'bcrypt', '~> 3.1.12'
gem 'bootsnap', require: false # Reduces boot times through caching; required in config/boot.rb
gem 'httparty'
gem 'jbuilder'
gem 'kamal'
gem 'nbayes'
gem 'pdf-reader'
gem "sqlite3", ">= 2.1"
gem 'pry-rails'
gem 'puma', '~> 6.0' # Use the Puma web server [https://github.com/puma/puma]
gem 'redis', '~> 5.0'
gem 'ruby-openai'
gem 'sidekiq'
gem 'stimulus-rails' # Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem 'turbo-rails' # Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem 'view_component'

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', platforms: %i[mri mingw x64_mingw]
  gem 'rubocop', require: false
  # gem 'rubocop-minitest', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
end

group :test do
  gem 'shoulda-matchers'
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'rspec-rails'
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem 'web-console'

  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  # gem "rack-mini-profiler"

  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"
end
