# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LegalDocuments do
  describe '.notify_change!' do
    let!(:legacy) { create(:user) }
    let!(:current) { create(:user, consents: { 'terms_version' => described_class::VERSION }) }

    it 'mails accounts that accepted an older version, once' do
      expect { described_class.notify_change! }
        .to have_enqueued_mail(LegalMailer, :terms_change).with(legacy).once
      expect(legacy.reload.consents['terms_notice']).to eq(described_class::VERSION)
      expect(current.reload.consents).not_to have_key('terms_notice')

      expect { described_class.notify_change! }.not_to have_enqueued_mail(LegalMailer, :terms_change)
    end
  end
end
