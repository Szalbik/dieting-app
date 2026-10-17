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
      line_items: [{ price: Rails.application.credentials.dig(:stripe, :"#{interval}_price_id"), quantity: 1 }],
      metadata: { interval: interval }, # read back by the purchase confirmation mail
      # The JDG is the seller (Terms); Managed Payments would make Stripe merchant of record.
      managed_payments: { enabled: false },
      # Owner decision: no buy-now-pay-later; card + BLIK (+ wallets) come from the Dashboard config.
      excluded_payment_method_types: ['klarna'],
      locale: 'pl',
      # Pro is a digital service: the consumer keeps the 14-day withdrawal right. Starting at once needs
      # an express request (art. 21 ust. 2 upk); on withdrawal they pay pro rata (art. 35) — Regulamin §6.
      consent_collection: { terms_of_service: 'required' },
      custom_text: {
        terms_of_service_acceptance: {
          message: "Akceptuję [Regulamin](#{terms_url}) i żądam rozpoczęcia świadczenia usługi przed " \
                   'upływem 14-dniowego terminu na odstąpienie od umowy. Rozumiem, że w razie odstąpienia ' \
                   'zapłacę za okres korzystania do chwili odstąpienia.',
        },
        # Art. 17 ust. 3 upk: the order step must state the obligation to pay.
        submit: { message: 'Klikając przycisk, składasz zamówienie z obowiązkiem zapłaty.' },
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

  def interval
    User::PRO_PRICES_PLN.key?(params[:interval]&.to_sym) ? params[:interval] : 'monthly'
  end

  def ensure_can_upgrade
    if !payments_enabled?
      redirect_to profile_path, notice: 'Plan Pro będzie dostępny wkrótce.'
    elsif Current.user.subscribed?
      redirect_to profile_path, notice: 'Masz już aktywny plan Pro.'
    end
  end
end
