# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Legal pages', type: :request do
  describe 'terms of service' do
    before { get terms_path }

    it 'renders without authentication with the current version' do
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Regulamin serwisu AsystentDiety', '13.10.2026')
    end

    it 'grants the 14-day withdrawal right with pro-rata payment and the model form' do
      expect(response.body).to include('14 dni od dnia jej zawarcia', 'art. 35', 'wzór formularza odstąpienia')
      expect(response.body).not_to include('38 pkt 13', 'utrat')
    end

    it 'covers consumer-rights traders, complaints silence rule and drops the ODR platform' do
      expect(response.body).to include('Przedsiębiorca na prawach konsumenta', 'Brak odpowiedzi w tym terminie')
      expect(response.body).not_to include('ec.europa.eu/consumers/odr', 'Usługodawca może wydłużyć')
    end

    it 'renders plan limits and prices from the code constants' do
      expect(response.body).to include("#{User::AI_QUOTA_LIMITS.fetch(:free)} operację AI",
                                       "#{User::AI_QUOTA_LIMITS.fetch(:pro)} operacje AI", '19,90 zł', '199 zł')
    end
  end

  describe 'privacy policy' do
    before { get privacy_path }

    it 'renders without authentication' do
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Polityka prywatności AsystentDiety')
    end

    it 'relies on explicit consent for health data without contradicting itself' do
      expect(response.body).to include('Art. 9 ust. 2 lit. a RODO', 'wyraźnej zgody')
      expect(response.body).not_to include('nie jest przeznaczony do przetwarzania danych o stanie zdrowia')
    end

    it 'names the actual recipients' do
      expect(response.body).to include('Stripe Payments Europe', 'OpenAI Ireland', 'Resend', 'DigitalOcean',
                                       'Honeybadger', 'odrębny administrator')
    end
  end

  describe 'cookies policy' do
    before { get cookies_policy_path }

    it 'cites the electronic communications act instead of the repealed telecoms law' do
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Polityka cookies AsystentDiety', 'Prawo komunikacji elektronicznej',
                                       'localStorage')
      expect(response.body).not_to include('telekomunikac')
    end
  end
end
