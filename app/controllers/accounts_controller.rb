# frozen_string_literal: true

# Self-service account deletion from the profile, confirmed with the password.
class AccountsController < ApplicationController
  rate_limit to: 5, within: 3.minutes, only: :destroy,
             with: -> { redirect_to profile_path, alert: 'Zbyt wiele prób. Spróbuj ponownie za kilka minut.' }

  def destroy
    unless Current.user.authenticate(params[:password].to_s)
      redirect_to profile_path, alert: 'Nieprawidłowe hasło — konto nie zostało usunięte.'
      return
    end

    Current.user.close_account!
    cookies.delete(:session_id) # the session row went with the user
    response.headers['Clear-Site-Data'] = '"cache", "storage"' # as on logout: drop offline copies
    redirect_to root_path, notice: 'Konto i wszystkie dane zostały usunięte.'
  rescue ActiveRecord::ActiveRecordError => e
    Honeybadger.notify(e) if defined?(Honeybadger)
    redirect_to profile_path, alert: 'Nie udało się usunąć konta. Napisz na kontakt@asystentdiet.pl — usuniemy je ręcznie.'
  rescue Stripe::StripeError
    redirect_to profile_path,
                alert: 'Nie udało się anulować subskrypcji, więc konto nie zostało usunięte. ' \
                       'Spróbuj ponownie lub napisz na kontakt@asystentdiet.pl.'
  end
end
