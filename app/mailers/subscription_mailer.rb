# frozen_string_literal: true

# Confirmation of the Pro contract on a durable medium (art. 21 ust. 1 upk): price, renewal, the
# consumer's early-start request, withdrawal notice + model form, and the terms as an attachment.
class SubscriptionMailer < ApplicationMailer
  INTERVAL_LABELS = { 'monthly' => 'miesięczny', 'yearly' => 'roczny' }.freeze

  def confirmation(user, interval:, amount_total:)
    @user = user
    @interval_label = INTERVAL_LABELS[interval]
    @amount = BigDecimal(amount_total.to_i) / 100
    attachments["regulamin-asystentdiety-#{LegalDocuments::VERSION}.html"] = {
      mime_type: 'text/html', content: terms_document
    }
    mail to: user.email_address, subject: 'Potwierdzenie zamówienia Planu Pro — AsystentDiety'
  end

  private

  # The same partial as /regulamin, rendered with absolute links so the file stands on its own.
  def terms_document
    url = Rails.application.config.action_mailer.default_url_options || {}
    ApplicationController.renderer.new(
      http_host: [url[:host], url[:port]].compact.join(':'), https: url[:protocol] == 'https'
    ).render(template: 'subscription_mailer/terms_document', layout: false)
  end
end
