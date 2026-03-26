# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Classifier::Category, type: :service do
  around do |example|
    FileUtils.rm_f(described_class::PATH)
    example.run
    FileUtils.rm_f(described_class::PATH)
  end

  it 'returns a confirmed category for the same product name regardless of case and spacing' do
    category = create(:category, name: 'Nabial')
    ProductCategory.create!(
      product: Product.create!(name: '  MLEKO '),
      category: category,
      state: true
    )

    prediction = described_class.predict('mleko')

    expect(prediction[:name]).to eq('Nabial')
    expect(prediction[:state]).to be(true)
    expect(prediction[:confidence]).to eq(1.0)
  end

  it 'falls back to a similar confirmed product and ignores quantity tokens' do
    category = create(:category, name: 'Nabial')
    ProductCategory.create!(
      product: Product.create!(name: 'Mleko 500 ml'),
      category: category,
      state: true
    )

    prediction = described_class.predict('mleko 1 l')

    expect(prediction[:name]).to eq('Nabial')
    expect(prediction[:state]).to be(false)
    expect(prediction[:confidence]).to be >= described_class::SIMILARITY_THRESHOLD
  end

  it 'returns an empty prediction when no confirmed training data exists' do
    prediction = described_class.predict('cokolwiek')

    expect(prediction[:name]).to be_nil
    expect(prediction[:state]).to be(false)
    expect(prediction[:confidence]).to eq(0.0)
  end

  it 'persists the trained model to disk' do
    category = create(:category, name: 'Warzywa')
    ProductCategory.create!(
      product: Product.create!(name: 'Cebula'),
      category: category,
      state: true
    )

    described_class.train!

    expect(File.exist?(described_class::PATH)).to be(true)
  end
end
