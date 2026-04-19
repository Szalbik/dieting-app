# frozen_string_literal: true

require_relative 'boot'

require 'rails'
# Pick the frameworks you want:
require 'active_model/railtie'
require 'active_job/railtie'
require 'active_record/railtie'
require 'active_storage/engine'
require 'action_controller/railtie'
require 'action_mailer/railtie'
require 'action_mailbox/engine'
require 'action_text/engine'
require 'action_view/railtie'
require 'action_cable/engine'
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Rails Performance defaults to enabled; without Redis tests cannot run request specs.
RailsPerformance.enabled = false if Rails.env.test? && defined?(RailsPerformance)

module DietingApp
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0
    config.mission_control.jobs.base_controller_class = 'AdminController'
    config.mission_control.jobs.http_basic_auth_enabled = false

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.x.openai.diet_parsing_models = ActiveSupport::InheritableOptions.new(
      metadata: ENV.fetch('OPENAI_DIET_PARSER_METADATA_MODEL', 'gpt-4.1'),
      ingredients: ENV.fetch('OPENAI_DIET_PARSER_INGREDIENTS_MODEL', 'gpt-4.1'),
      instructions_nutrition: ENV.fetch('OPENAI_DIET_PARSER_INSTRUCTIONS_MODEL', 'gpt-5.1')
    )

    config.time_zone = 'Warsaw'
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil
  end
end
