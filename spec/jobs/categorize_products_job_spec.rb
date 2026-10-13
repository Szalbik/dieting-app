# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CategorizeProductsJob, type: :job do
  around do |example|
    FileUtils.rm_f(Classifier::Category::PATH)
    example.run
    FileUtils.rm_f(Classifier::Category::PATH)
  end

  it 'categorizes leftover products locally, then hands the rest to the AI fallback' do
    # Created before any category exists, so the create hook leaves it uncategorized.
    meal = create(:meal)
    product = Product.create!(name: 'Schab wieprzowy', meal: meal)
    leftover = Product.create!(name: 'Xyzzy', meal: meal)
    Product.create!(name: 'Orphan of a deleted diet') # never sent to the AI
    create(:category, name: 'Mięso i Ryby')
    ai = instance_double(Chat::ProductCategorizerService, call: nil)
    allow(Chat::ProductCategorizerService).to receive(:new).and_return(ai)

    described_class.perform_now

    expect(product.reload.category&.name).to eq('Mięso i Ryby')
    expect(Chat::ProductCategorizerService).to have_received(:new) do |products:|
      expect(products).to contain_exactly(leftover)
    end
  end
end
