# frozen_string_literal: true

Resend.api_key = Rails.application.credentials.dig(:resend, :api_key)

# ponytail: retries every Resend::Error, incl. permanent 4xx; narrow to ServerError if it gets noisy
ActiveSupport.on_load(:action_mailer) do
  ActionMailer::MailDeliveryJob.retry_on Resend::Error, wait: :polynomially_longer, attempts: 5
end
