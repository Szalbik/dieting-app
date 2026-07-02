# frozen_string_literal: true

class SubscriptionsController < ApplicationController
  def new
    if Current.user.subscribed?
      redirect_to profile_path, notice: 'Masz już aktywny plan Pro.'
      return
    end

    session = Stripe::Checkout::Session.create(
      mode: 'subscription',
      customer: Current.user.stripe_customer.id,
      line_items: [{ price: Rails.application.credentials.dig(:stripe, :monthly_price_id), quantity: 1 }],
      locale: 'pl',
      # Art. 38 pkt 13 ustawy o prawach konsumenta: wyraźna zgoda na natychmiastowe świadczenie
      # = utrata prawa odstąpienia; brak zgody blokuje zakup (Regulamin §6).
      consent_collection: { terms_of_service: 'required' },
      custom_text: {
        terms_of_service_acceptance: {
          message: 'Akceptuję [Regulamin](https://diety.rubydive.com/regulamin) i wyrażam zgodę na ' \
                   'natychmiastowe rozpoczęcie świadczenia usługi, przyjmując do wiadomości utratę ' \
                   'prawa odstąpienia od umowy (art. 38 pkt 13 ustawy o prawach konsumenta).',
        },
      },
      success_url: profile_url(checkout: 'success'),
      cancel_url: profile_url
    )

    redirect_to session.url, allow_other_host: true
  end

  def billing_portal
    session = Stripe::BillingPortal::Session.create(
      customer: Current.user.stripe_customer.id,
      return_url: profile_url,
      locale: 'pl'
    )

    redirect_to session.url, allow_other_host: true
  end
end
