# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubscriptionMailer do
  let(:user) { create(:user, email_address: 'kupujacy@example.com') }
  let(:mail) { described_class.confirmation(user, interval: 'yearly', amount_total: 19_900) }

  it 'confirms the Pro contract to the buyer' do
    expect(mail.to).to eq(['kupujacy@example.com'])
    expect(mail.subject).to include('Potwierdzenie', 'Planu Pro')
  end

  it 'carries the price, renewal, early-start request, withdrawal notice and model form' do
    body = mail.html_part.body.decoded
    expect(body).to include('199 zł', 'roczny', 'odnawia się automatycznie', 'żądanie rozpoczęcia świadczenia',
                            '14 dni', 'formularza odstąpienia', 'Damian Szalbierz', 'NIP 7812072186')
    expect(mail.text_part.body.decoded).to include('199 zł', 'odstąpi')
  end

  it 'attaches the terms of service as a standalone HTML document with absolute links' do
    attachment = mail.attachments.find { |a| a.filename.start_with?('regulamin') }
    html = attachment.body.decoded
    expect(attachment.mime_type).to eq('text/html')
    expect(html).to include('Regulamin serwisu AsystentDiety', LegalDocuments::VERSION.split('-').reverse.join('.'),
                            'http://example.com/polityka-prywatnosci')
  end
end
