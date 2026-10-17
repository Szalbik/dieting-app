# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DataRetentionJob do
  def blob(created_at)
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new('pdf'), filename: 'x.pdf').tap do |b|
      b.update_column(:created_at, created_at) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  it 'purges blobs left without an attachment for over a day, keeping fresh and attached ones' do
    orphan = blob(2.days.ago)
    fresh = blob(1.hour.ago) # may still be mid-upload
    attached = create(:diet, :with_pdf).pdf.blob
    attached.update_column(:created_at, 2.days.ago) # rubocop:disable Rails/SkipsModelValidations

    described_class.perform_now

    expect(ActiveStorage::Blob.exists?(orphan.id)).to be(false)
    expect(ActiveStorage::Blob.exists?(fresh.id)).to be(true)
    expect(ActiveStorage::Blob.exists?(attached.id)).to be(true)
  end

  it 'deletes login sessions older than 12 months' do
    user = create(:user)
    old = user.sessions.create!(created_at: 13.months.ago)
    recent = user.sessions.create!(created_at: 11.months.ago)

    described_class.perform_now

    expect(Session.exists?(old.id)).to be(false)
    expect(Session.exists?(recent.id)).to be(true)
  end

  it 'deletes products left behind by deleted diets, keeping live and still-referenced ones' do
    orphan = create(:product, meal: nil, diet_set: nil)
    live = create(:product)
    in_cart = create(:product, meal: nil, diet_set: nil)
    create(:shopping_cart_item, product: in_cart, shopping_cart: create(:user).owned_shopping_cart)

    described_class.perform_now

    expect(Product.exists?(orphan.id)).to be(false)
    expect(Product.exists?(live.id)).to be(true)
    expect(Product.exists?(in_cart.id)).to be(true)
  end

  it 'deletes dietitian waitlist entries older than 2 years' do
    old = create(:dietitian_waitlist_entry, created_at: 25.months.ago)
    recent = create(:dietitian_waitlist_entry)

    described_class.perform_now

    expect(DietitianWaitlistEntry.exists?(old.id)).to be(false)
    expect(DietitianWaitlistEntry.exists?(recent.id)).to be(true)
  end
end
