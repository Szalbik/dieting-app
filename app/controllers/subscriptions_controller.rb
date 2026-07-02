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
