# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DietBuilder do
  subject(:process_pages) do
    diet.pdf.open do |file|
      PDF::Reader.open(file) do |reader|
        reader.pages.each do |page|
          builder.process_page(page)
        end
      end
    end
  end
  subject(:save_ingredients) { builder.save_ingredients }

  describe '.new' do
    let(:diet) { create(:diet) }
    subject { described_class.new(diet) }

    it { expect(subject).to be_an_instance_of(DietBuilder) }
  end

  describe '#process_page with pdf' do
    let(:diet) { create(:diet, :with_pdf) }
    let(:builder) { described_class.new(diet) }

    it 'processes the page' do
      process_pages
    end

    it 'creates a diet set' do
      process_pages
      save_ingredients
      expect(diet.diet_sets.count).to eq(7)
    end

    it 'creates a product' do
      process_pages
      save_ingredients
      expect(Product.count).not_to eq(0)
    end

    it 'cretes correct amount of products for Diet Set 1' do
      process_pages
      save_ingredients
      diet_set = diet.diet_sets.find_by(name: 'Zestaw 1')
      expect(diet_set.products.count).to eq(30)
    end

    it 'cretes correct amount of products for Diet Set 2' do
      process_pages
      save_ingredients
      diet_set = diet.diet_sets.find_by(name: 'Zestaw 2')
      expect(diet_set.products.count).to eq(28)
    end

    it 'cretes correct amount of products for Diet Set 3' do
      process_pages
      save_ingredients
      diet_set = diet.diet_sets.find_by(name: 'Zestaw 3')
      expect(diet_set.products.count).to eq(29)
    end

    it 'cretes correct amount of products for Diet Set 4' do
      process_pages
      save_ingredients
      diet_set = diet.diet_sets.find_by(name: 'Zestaw 4')
      expect(diet_set.products.count).to eq(28)
    end

    it 'cretes correct amount of products for Diet Set 5' do
      process_pages
      save_ingredients
      diet_set = diet.diet_sets.find_by(name: 'Zestaw 5')
      expect(diet_set.products.count).to eq(32)
    end

    it 'cretes correct amount of products for Diet Set 6' do
      process_pages
      save_ingredients
      diet_set = diet.diet_sets.find_by(name: 'Zestaw 6')
      expect(diet_set.products.count).to eq(27)
    end

    it 'cretes correct amount of products for Diet Set 7' do
      process_pages
      save_ingredients
      diet_set = diet.diet_sets.find_by(name: 'Zestaw 7')
      expect(diet_set.products.count).to eq(29)
    end
  end

  describe '#process_page with long pdf' do
    let(:diet) { create(:diet, :with_long_pdf) }
    let(:builder) { described_class.new(diet) }

    it 'processes the page' do
      process_pages
    end

    it 'creates a diet set' do
      process_pages
      save_ingredients
      expect(diet.diet_sets.count).to eq(14)
    end

    it 'creates a product' do
      process_pages
      save_ingredients
      expect(Product.count).not_to eq(0)
    end

    it 'cretes correct amount of products for Diet Set 1' do
      process_pages
      save_ingredients
      diet_set = diet.diet_sets.find_by(name: 'Zestaw 1')
      expect(diet_set.products.count).to eq(23)
    end

    it 'cretes correct amount of products for Diet Set 2' do
      process_pages
      save_ingredients
      diet_set = diet.diet_sets.find_by(name: 'Zestaw 2')
      expect(diet_set.products.count).to eq(30)
    end

    it 'cretes correct amount of products for Diet Set 3' do
      process_pages
      save_ingredients
      diet_set = diet.diet_sets.find_by(name: 'Zestaw 3')
      expect(diet_set.products.count).to eq(32)
    end

    it 'cretes correct amount of products for Diet Set 4' do
      process_pages
      save_ingredients
      diet_set = diet.diet_sets.find_by(name: 'Zestaw 4')
      expect(diet_set.products.count).to eq(26)
    end

    it 'cretes correct amount of products for Diet Set 5' do
      process_pages
      save_ingredients
      diet_set = diet.diet_sets.find_by(name: 'Zestaw 5')
      expect(diet_set.products.count).to eq(23)
    end

    it 'cretes correct amount of products for Diet Set 6' do
      process_pages
      save_ingredients
      diet_set = diet.diet_sets.find_by(name: 'Zestaw 6')
      expect(diet_set.products.count).to eq(24)
    end

    it 'cretes correct amount of products for Diet Set 7' do
      process_pages
      save_ingredients
      diet_set = diet.diet_sets.find_by(name: 'Zestaw 7')
      expect(diet_set.products.count).to eq(26)
    end

    it 'cretes correct amount of products for Diet Set 8' do
      process_pages
      save_ingredients
      diet_set = diet.diet_sets.find_by(name: 'Zestaw 8')
      expect(diet_set.products.count).to eq(24)
    end

    it 'cretes correct amount of products for Diet Set 9' do
      process_pages
      save_ingredients
      diet_set = diet.diet_sets.find_by(name: 'Zestaw 9')
      expect(diet_set.products.count).to eq(22)
    end

    it 'cretes correct amount of products for Diet Set 10' do
      process_pages
      save_ingredients
      diet_set = diet.diet_sets.find_by(name: 'Zestaw 10')
      expect(diet_set.products.count).to eq(25)
    end

    it 'cretes correct amount of products for Diet Set 11' do
      process_pages
      save_ingredients
      diet_set = diet.diet_sets.find_by(name: 'Zestaw 11')
      expect(diet_set.products.count).to eq(26)
    end

    it 'cretes correct amount of products for Diet Set 12' do
      process_pages
      save_ingredients
      diet_set = diet.diet_sets.find_by(name: 'Zestaw 12')
      expect(diet_set.products.count).to eq(25)
    end

    it 'cretes correct amount of products for Diet Set 13' do
      # nie zgadzają się przyprawy
      process_pages
      save_ingredients
      diet_set = diet.diet_sets.find_by(name: 'Zestaw 13')
      expect(diet_set.products.count).to eq(24)
    end

    it 'cretes correct amount of products for Diet Set 14' do
      process_pages
      save_ingredients
      diet_set = diet.diet_sets.find_by(name: 'Zestaw 14')
      expect(diet_set.products.count).to eq(35)
    end
  end
end
