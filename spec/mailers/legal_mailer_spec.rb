# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LegalMailer do
  let(:mail) { described_class.terms_change(create(:user, email_address: 'stary@example.com')) }

  it 'announces the new documents, their effective date and the way out' do
    body = mail.html_part.body.decoded
    expect(mail.to).to eq(['stary@example.com'])
    expect(mail.subject).to include('Zmiany w Regulaminie')
    expect(body).to include(LegalDocuments::EFFECTIVE_ON.strftime('%d.%m.%Y'), 'http://example.com/regulamin',
                            'http://example.com/polityka-prywatnosci', 'usuwając konto', 'odstąpi')
    expect(mail.text_part.body.decoded).to include(LegalDocuments::EFFECTIVE_ON.strftime('%d.%m.%Y'))
  end
end
