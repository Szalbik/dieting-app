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

    it 'mails accounts that accepted an older version, once, and stamps them after delivery' do
      expect { described_class.notify_change! }.to change { ActionMailer::Base.deliveries.size }.by(1)
      expect(ActionMailer::Base.deliveries.last.to).to eq([legacy.email_address])
      expect(legacy.reload.consents['terms_notice']).to eq(described_class::VERSION)
      expect(current.reload.consents).not_to have_key('terms_notice')

      expect { described_class.notify_change! }.not_to(change { ActionMailer::Base.deliveries.size })
    end

    it 'leaves a user unstamped when delivery fails, so the next run retries them' do
      failing = instance_double(ActionMailer::MessageDelivery)
      allow(failing).to receive(:deliver_now).and_raise(Resend::Error, 'rate limited')
      allow(LegalMailer).to receive(:terms_change).and_call_original
      allow(LegalMailer).to receive(:terms_change).with(legacy).and_return(failing)

      expect(described_class.notify_change!).to eq(0)
      expect(legacy.reload.consents).not_to have_key('terms_notice')

      allow(LegalMailer).to receive(:terms_change).with(legacy).and_call_original
      expect(described_class.notify_change!).to eq(1)
      expect(legacy.reload.consents['terms_notice']).to eq(described_class::VERSION)
    end
  end
end
