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
  end

  describe 'preset_category (LLM choice from PopulateDietFromJsonJob)' do
    let!(:dairy) { create(:category, name: 'Nabiał') }
    let!(:grains) { create(:category, name: 'Produkty zbożowe') }

    it 'wins over local guessing as an unconfirmed assignment' do
      product = Product.create!(name: 'Płatki owsiane', preset_category: dairy)

      expect(product.reload.product_category).to have_attributes(category: dairy, state: false)
    end

    it 'yields to a category an admin confirmed for the same name' do
      ProductCategory.create!(product: Product.create!(name: 'Kasza jaglana'), category: grains, state: true)

      product = Product.create!(name: 'kasza jaglana ', preset_category: dairy)

      expect(product.reload.product_category).to have_attributes(category: grains, state: true)
    end
  end
end
