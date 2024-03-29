# frozen_string_literal: true

Sidekiq.configure_server do |config|
  config.redis = { url: Rails.application.credentials.redis_url, network_timeout: 25, pool_timeout: 25 }
end

Sidekiq.configure_client do |config|
  config.redis = { url: Rails.application.credentials.redis_url, network_timeout: 25, pool_timeout: 25 }
end
