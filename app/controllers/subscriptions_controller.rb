# frozen_string_literal: true

class SubscriptionsController < ApplicationController
  before_action :ensure_can_upgrade, only: %i[new create]

  # Plan summary + recurring/BLIK terms; Stripe requires showing them before the BLIK code is collected.
  def new; end

  def create
    session = Stripe::Checkout::Session.create(
      mode: 'subscription',
      customer: Current.user.stripe_customer.id,
      client_reference_id: Current.user.id,
      line_items: [{ price: Rails.application.credentials.dig(:stripe, :monthly_price_id), quantity: 1 }],
      # The JDG is the seller (Terms); Managed Payments would make Stripe merchant of record.
      managed_payments: { enabled: false },
      # Owner decision: no buy-now-pay-later; card + BLIK (+ wallets) come from the Dashboard config.
      excluded_payment_method_types: ['klarna'],
      locale: 'pl',
      # Art. 38 pkt 13 ustawy o prawach konsumenta: wyraźna zgoda na natychmiastowe świadczenie
      # = utrata prawa odstąpienia; brak zgody blokuje zakup (Regulamin §6).
      consent_collection: { terms_of_service: 'required' },
      custom_text: {
        terms_of_service_acceptance: {
          message: "Akceptuję [Regulamin](#{terms_url}) i wyrażam zgodę na " \
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

  private

  def ensure_can_upgrade
    if !payments_enabled?
      redirect_to profile_path, notice: 'Plan Pro będzie dostępny wkrótce.'
    elsif Current.user.subscribed?
      redirect_to profile_path, notice: 'Masz już aktywny plan Pro.'
    end
  end
end
