# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProductCategory, type: :model do
  include ActiveJob::TestHelper

  around do |example|
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs
    example.run
    clear_enqueued_jobs
    clear_performed_jobs
    ActiveJob::Base.queue_adapter = previous_adapter
  end

  it 'enqueues model retraining when a pending category becomes confirmed' do
    category = create(:category, name: 'Nabial')
    product_category = ProductCategory.create!(
      product: Product.create!(name: 'Mleko'),
      category: category,
      state: false
    )

    expect do
      product_category.update!(state: true)
    end.to have_enqueued_job(TrainCategoryModelJob)
  end

  it 'does not enqueue model retraining for edits that stay unconfirmed' do
    original_category = create(:category, name: 'Nabial')
    new_category = create(:category, name: 'Napoje')
    product_category = ProductCategory.create!(
      product: Product.create!(name: 'Mleko'),
      category: original_category,
      state: false
    )

    expect do
      product_category.update!(category: new_category)
    end.not_to have_enqueued_job(TrainCategoryModelJob)
  end
end
