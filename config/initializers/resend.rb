# frozen_string_literal: true

Resend.api_key = Rails.application.credentials.dig(:resend, :api_key)

# Retry only transient failures (429, 500). Bad key / unverified domain (400/401/422 →
# InvalidRequestError) and a missing key fail the mail job at once so Honeybadger sees them.
ActiveSupport.on_load(:action_mailer) do
  ActionMailer::MailDeliveryJob.retry_on Resend::Error::RateLimitExceededError,
                                         Resend::Error::InternalServerError,
                                         wait: :polynomially_longer, attempts: 5
end
