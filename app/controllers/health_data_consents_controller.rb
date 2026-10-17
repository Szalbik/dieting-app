# frozen_string_literal: true

# Explicit art. 9 RODO consent for health-related diet data: granted here or with the first PDF upload,
# withdrawn here (art. 7(3) — as easy as giving it). Without it, AI operations are refused.
class HealthDataConsentsController < ApplicationController
  def create
    Current.user.record_consent!(:health_data)
    redirect_to profile_path, notice: 'Zgoda na przetwarzanie danych dotyczących zdrowia została udzielona.'
  end

  def destroy
    Current.user.update_column(:consents, Current.user.consents.except('health_data')) # rubocop:disable Rails/SkipsModelValidations
    redirect_to profile_path, notice: 'Zgoda została wycofana. Wczytywanie diet z PDF jest niedostępne do jej ponownego udzielenia.'
  end
end
