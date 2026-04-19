# frozen_string_literal: true

require 'rails_helper'

# Rubocop: disable Metrics/BlockLength
RSpec.describe DietBuilder do
  subject(:save_ingredients) { builder.save_ingredients }

  let(:process_pages) do
    diet.pdf.open do |file|
      PDF::Reader.open(file) do |reader|
        reader.pages.each do |page|
          builder.process_page(page)
        end
      end
    end
  end

  def expect_diet_structure(diet, expected_sets)
    expect(diet.diet_sets.count).to eq(expected_sets.size)

    expected_sets.each do |set_name, expected_data|
      diet_set = diet.diet_sets.find_by(name: set_name)

      aggregate_failures(set_name) do
        expect(diet_set).to be_present
        expect(diet_set.products.count).to eq(expected_data[:products])
        expect(diet_set.meals.map { |meal| meal.products.count }).to eq(expected_data[:meals])
      end
    end
  end

  describe '.new' do
    subject { described_class.new(diet) }

    let(:diet) { create(:diet) }

    it { is_expected.to be_an_instance_of(described_class) }
  end

  describe '#process_page with 2 pdf' do
    let(:pdf_trait) { :with_pdf }
    let(:diet) { create(:diet, pdf_trait) }
    let(:builder) { described_class.new(diet) }

    it 'processes the page' do
      process_pages
    end

    shared_examples 'imports parsed diet' do
      before do
        process_pages
        save_ingredients
      end

      it 'creates products' do
        expect(Product.count).not_to eq(0)
      end

      it 'creates the expected diet structure', :aggregate_failures do
        expect_diet_structure(diet, expected_sets)
      end
    end

    context 'when parsing diet_for_one_week.pdf' do
      let(:pdf_trait) { :with_pdf }
      let(:expected_sets) do
        {
          'Zestaw 1' => { products: 30, meals: [6, 2, 15, 7] },
          'Zestaw 2' => { products: 28, meals: [4, 12, 7, 5] },
          'Zestaw 3' => { products: 29, meals: [6, 5, 7, 11] },
          'Zestaw 4' => { products: 28, meals: [5, 7, 10, 6] },
          'Zestaw 5' => { products: 32, meals: [5, 7, 11, 9] },
          'Zestaw 6' => { products: 27, meals: [6, 3, 13, 5] },
          'Zestaw 7' => { products: 29, meals: [5, 5, 14, 5] }
        }
      end

      include_examples 'imports parsed diet'
    end

    context 'when parsing diet_for_one_week2.pdf' do
      let(:pdf_trait) { :with_pdf2 }
      let(:expected_sets) do
        {
          'Zestaw 1' => { products: 25, meals: [4, 7, 9, 2, 3] },
          'Zestaw 2' => { products: 30, meals: [4, 5, 12, 2, 7] },
          'Zestaw 3' => { products: 28, meals: [6, 2, 9, 1, 10] },
          'Zestaw 4' => { products: 26, meals: [6, 2, 10, 2, 6] },
          'Zestaw 5' => { products: 22, meals: [4, 2, 10, 2, 4] },
          'Zestaw 6' => { products: 26, meals: [4, 5, 10, 2, 5] },
          'Zestaw 7' => { products: 29, meals: [5, 5, 11, 2, 6] }
        }
      end

      include_examples 'imports parsed diet'
    end

    context 'when parsing diet_for_two_weeks.pdf' do
      let(:pdf_trait) { :with_long_pdf }
      let(:expected_sets) do
        {
          'Zestaw 1' => { products: 23, meals: [4, 7, 8, 4] },
          'Zestaw 2' => { products: 30, meals: [3, 6, 14, 7] },
          'Zestaw 3' => { products: 32, meals: [5, 4, 11, 12] },
          'Zestaw 4' => { products: 26, meals: [3, 5, 12, 6] },
          'Zestaw 5' => { products: 23, meals: [6, 5, 7, 5] },
          'Zestaw 6' => { products: 24, meals: [5, 2, 12, 5] },
          'Zestaw 7' => { products: 26, meals: [4, 5, 11, 6] },
          'Zestaw 8' => { products: 24, meals: [4, 4, 12, 4] },
          'Zestaw 9' => { products: 22, meals: [5, 3, 9, 5] },
          'Zestaw 10' => { products: 25, meals: [4, 6, 9, 6] },
          'Zestaw 11' => { products: 26, meals: [3, 2, 13, 8] },
          'Zestaw 12' => { products: 25, meals: [3, 5, 13, 4] },
          'Zestaw 13' => { products: 24, meals: [7, 4, 8, 5] },
          'Zestaw 14' => { products: 35, meals: [6, 3, 14, 12] }
        }
      end

      include_examples 'imports parsed diet'
    end
  end
end
