# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Product, type: :model do
  include ActiveJob::TestHelper

  around do |example|
    FileUtils.rm_f(Classifier::Category::PATH)
    perform_enqueued_jobs do
      clear_enqueued_jobs
      clear_performed_jobs
      example.run
    end
    FileUtils.rm_f(Classifier::Category::PATH)
  end

  it 'categorizes obvious products synchronously without relying on the background job' do
    category = create(:category, name: 'Mięso i Ryby')

    product = Product.create!(name: 'Wieprzowina schab, chudy')

    expect(category).to be_present
    expect(product.reload.category&.name).to eq('Mięso i Ryby')
    expect(enqueued_jobs.none? { |job| job[:job] == CategorizeProductJob }).to be(true)
  end
end
