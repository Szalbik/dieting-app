# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LegalDocuments do
  include ActiveSupport::Testing::TimeHelpers

  describe '.notify_change!' do
    let!(:legacy) { create(:user) }
    let!(:current) { create(:user, consents: { 'terms_version' => described_class::VERSION }) }

    before { travel_to(described_class::EFFECTIVE_ON - 14.days) }

    it 'refuses to send when fewer than 14 days are left before EFFECTIVE_ON' do
      travel_to(described_class::EFFECTIVE_ON - 13.days)
      expect { described_class.notify_change! }.to raise_error(ArgumentError, /EFFECTIVE_ON/)
    end

    it 'mails accounts that accepted an older version, once' do
      expect { described_class.notify_change! }
        .to have_enqueued_mail(LegalMailer, :terms_change).with(legacy).once
      expect(legacy.reload.consents['terms_notice']).to eq(described_class::VERSION)
      expect(current.reload.consents).not_to have_key('terms_notice')

      expect { described_class.notify_change! }.not_to have_enqueued_mail(LegalMailer, :terms_change)
    end
  end
end
