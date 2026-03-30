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

  describe '.new' do
    subject { described_class.new(diet) }

    let(:diet) { create(:diet) }

    it { is_expected.to be_an_instance_of(described_class) }
  end

  describe '#process_page with 2 pdf' do
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

    context 'when counting Products for first diet' do
      before do
        process_pages
        save_ingredients
      end

      it 'creates a product' do
        expect(Product.count).not_to eq(0)
      end

      it 'cretes correct amount of products for Diet Set 1' do
        diet_set = diet.diet_sets.find_by(name: 'Zestaw 1')
        expect(diet_set.products.count).to eq(30)
      end

      context 'when counting Products for meals in 1' do
        let(:diet_set) { diet.diet_sets.find_by(name: 'Zestaw 1') }

        it 'creates a product' do
          expect(diet_set.meals[0].products.count).to eq(6)
          expect(diet_set.meals[1].products.count).to eq(2)
          expect(diet_set.meals[2].products.count).to eq(15)
          expect(diet_set.meals[3].products.count).to eq(7)
        end
      end

      it 'cretes correct amount of products for Diet Set 2' do
        diet_set = diet.diet_sets.find_by(name: 'Zestaw 2')
        expect(diet_set.products.count).to eq(28)
      end

      context 'when counting Products for meals in 2' do
        let(:diet_set) { diet.diet_sets.find_by(name: 'Zestaw 2') }

        it 'creates a product' do
          expect(diet_set.meals[0].products.count).to eq(4)
          expect(diet_set.meals[1].products.count).to eq(12)
          expect(diet_set.meals[2].products.count).to eq(7)
          expect(diet_set.meals[3].products.count).to eq(5)
        end
      end

      it 'cretes correct amount of products for Diet Set 3' do
        diet_set = diet.diet_sets.find_by(name: 'Zestaw 3')
        expect(diet_set.products.count).to eq(29)
      end

      context 'when counting Products for meals in 3' do
        let(:diet_set) { diet.diet_sets.find_by(name: 'Zestaw 3') }

        it 'creates a product' do
          expect(diet_set.meals[0].products.count).to eq(6)
          expect(diet_set.meals[1].products.count).to eq(5)
          expect(diet_set.meals[2].products.count).to eq(7)
          expect(diet_set.meals[3].products.count).to eq(11)
        end
      end

      it 'cretes correct amount of products for Diet Set 4' do
        diet_set = diet.diet_sets.find_by(name: 'Zestaw 4')
        expect(diet_set.products.count).to eq(28)
      end

      context 'when counting Products for meals in 4' do
        let(:diet_set) { diet.diet_sets.find_by(name: 'Zestaw 4') }

        it 'creates a product' do
          expect(diet_set.meals[0].products.count).to eq(5)
          expect(diet_set.meals[1].products.count).to eq(7)
          expect(diet_set.meals[2].products.count).to eq(10)
          expect(diet_set.meals[3].products.count).to eq(6)
        end
      end

      it 'cretes correct amount of products for Diet Set 5' do
        diet_set = diet.diet_sets.find_by(name: 'Zestaw 5')
        expect(diet_set.products.count).to eq(32)
      end

      context 'when counting Products for meals in 5' do
        let(:diet_set) { diet.diet_sets.find_by(name: 'Zestaw 5') }

        it 'creates a product' do
          expect(diet_set.meals[0].products.count).to eq(5)
          expect(diet_set.meals[1].products.count).to eq(7)
          expect(diet_set.meals[2].products.count).to eq(11)
          expect(diet_set.meals[3].products.count).to eq(9)
        end
      end

      it 'cretes correct amount of products for Diet Set 6' do
        diet_set = diet.diet_sets.find_by(name: 'Zestaw 6')
        expect(diet_set.products.count).to eq(27)
      end

      context 'when counting Products for meals in 6' do
        let(:diet_set) { diet.diet_sets.find_by(name: 'Zestaw 6') }

        it 'creates a product' do
          expect(diet_set.meals[0].products.count).to eq(6)
          expect(diet_set.meals[1].products.count).to eq(3)
          expect(diet_set.meals[2].products.count).to eq(13)
          expect(diet_set.meals[3].products.count).to eq(5)
        end
      end

      it 'cretes correct amount of products for Diet Set 7' do
        diet_set = diet.diet_sets.find_by(name: 'Zestaw 7')
        expect(diet_set.products.count).to eq(29)
      end

      context 'when counting Products for meals in 7' do
        let(:diet_set) { diet.diet_sets.find_by(name: 'Zestaw 7') }

        it 'creates a product' do
          expect(diet_set.meals[0].products.count).to eq(5)
          expect(diet_set.meals[1].products.count).to eq(5)
          expect(diet_set.meals[2].products.count).to eq(14)
          expect(diet_set.meals[3].products.count).to eq(5)
        end
      end
    end

    context 'when counting Products for 3 pdf' do
      let(:diet) { create(:diet, :with_pdf2) }

      before do
        process_pages
        save_ingredients
      end

      context 'when counting Products for first set' do
        let(:diet_set) { diet.diet_sets.find_by(name: 'Zestaw 1') }

        it { expect(diet_set.meals[0].products.count).to eq(4) }
        it { expect(diet_set.meals[1].products.count).to eq(7) }
        it { expect(diet_set.meals[2].products.count).to eq(9) }
        it { expect(diet_set.meals[3].products.count).to eq(2) }
        it { expect(diet_set.meals[4].products.count).to eq(3) }

        it { expect(diet_set.products.count).to eq(25) }
      end

      context 'when counting Products for second set' do
        let(:diet_set) { diet.diet_sets.find_by(name: 'Zestaw 2') }

        it { expect(diet_set.meals[0].products.count).to eq(4) }
        it { expect(diet_set.meals[1].products.count).to eq(5) }
        it { expect(diet_set.meals[2].products.count).to eq(12) }
        it { expect(diet_set.meals[3].products.count).to eq(2) }
        it { expect(diet_set.meals[4].products.count).to eq(7) }

        it { expect(diet_set.products.count).to eq(30) }
      end

      context 'when counting Products for third set' do
        let(:diet_set) { diet.diet_sets.find_by(name: 'Zestaw 3') }

        it { expect(diet_set.meals[0].products.count).to eq(6) }
        it { expect(diet_set.meals[1].products.count).to eq(2) }
        it { expect(diet_set.meals[2].products.count).to eq(9) }
        it { expect(diet_set.meals[3].products.count).to eq(1) }
        it { expect(diet_set.meals[4].products.count).to eq(10) }

        it { expect(diet_set.products.count).to eq(28) }
      end

      context 'when counting Products for fourth set' do
        let(:diet_set) { diet.diet_sets.find_by(name: 'Zestaw 4') }

        it { expect(diet_set.meals[0].products.count).to eq(6) }
        it { expect(diet_set.meals[1].products.count).to eq(2) }
        it { expect(diet_set.meals[2].products.count).to eq(10) }
        it { expect(diet_set.meals[3].products.count).to eq(2) }
        it { expect(diet_set.meals[4].products.count).to eq(6) }

        it { expect(diet_set.products.count).to eq(26) }
      end

      context 'when counting Products for fifth set' do
        let(:diet_set) { diet.diet_sets.find_by(name: 'Zestaw 5') }

        it { expect(diet_set.meals[0].products.count).to eq(4) }
        it { expect(diet_set.meals[1].products.count).to eq(2) }
        it { expect(diet_set.meals[2].products.count).to eq(10) }
        it { expect(diet_set.meals[3].products.count).to eq(2) }
        it { expect(diet_set.meals[4].products.count).to eq(4) }

        it { expect(diet_set.products.count).to eq(22) }
      end

      context 'when counting Products for sixth set' do
        let(:diet_set) { diet.diet_sets.find_by(name: 'Zestaw 6') }

        it { expect(diet_set.meals[0].products.count).to eq(4) }
        it { expect(diet_set.meals[1].products.count).to eq(5) }
        it { expect(diet_set.meals[2].products.count).to eq(10) }
        it { expect(diet_set.meals[3].products.count).to eq(2) }
        it { expect(diet_set.meals[4].products.count).to eq(5) }

        it { expect(diet_set.products.count).to eq(26) }
      end

      context 'when counting Products for seventh set' do
        let(:diet_set) { diet.diet_sets.find_by(name: 'Zestaw 7') }

        it { expect(diet_set.meals[0].products.count).to eq(5) }
        it { expect(diet_set.meals[1].products.count).to eq(5) }
        it { expect(diet_set.meals[2].products.count).to eq(11) }
        it { expect(diet_set.meals[3].products.count).to eq(2) }
        it { expect(diet_set.meals[4].products.count).to eq(6) }

        it { expect(diet_set.products.count).to eq(29) }
      end
    end

    context 'when counting Products for 1 pdf' do
      let(:diet) { create(:diet, :with_long_pdf) }

      before do
        process_pages
        save_ingredients
      end

      it 'creates a product' do
        expect(Product.count).not_to eq(0)
      end

      it 'cretes correct amount of products for Diet Set 1' do
        diet_set = diet.diet_sets.find_by(name: 'Zestaw 1')
        expect(diet_set.products.count).to eq(23)
      end

      context 'when counting Products for meals in 1' do
        let(:diet_set) { diet.diet_sets.find_by(name: 'Zestaw 1') }

        it 'creates a product' do
          expect(diet_set.meals[0].products.count).to eq(4)
          expect(diet_set.meals[1].products.count).to eq(7)
          expect(diet_set.meals[2].products.count).to eq(8)
          expect(diet_set.meals[3].products.count).to eq(4)
        end
      end

      it 'cretes correct amount of products for Diet Set 2' do
        diet_set = diet.diet_sets.find_by(name: 'Zestaw 2')
        expect(diet_set.products.count).to eq(30)
      end

      context 'when counting Products for meals in 2' do
        let(:diet_set) { diet.diet_sets.find_by(name: 'Zestaw 2') }

        it 'creates a product' do
          expect(diet_set.meals[0].products.count).to eq(3)
          expect(diet_set.meals[1].products.count).to eq(6)
          expect(diet_set.meals[2].products.count).to eq(14)
          expect(diet_set.meals[3].products.count).to eq(7)
        end
      end

      it 'cretes correct amount of products for Diet Set 3' do
        diet_set = diet.diet_sets.find_by(name: 'Zestaw 3')
        expect(diet_set.products.count).to eq(32)
      end

      context 'when counting Products for meals in 3' do
        let(:diet_set) { diet.diet_sets.find_by(name: 'Zestaw 3') }

        it 'creates a product' do
          expect(diet_set.meals[0].products.count).to eq(5)
          expect(diet_set.meals[1].products.count).to eq(4)
          expect(diet_set.meals[2].products.count).to eq(11)
          expect(diet_set.meals[3].products.count).to eq(12)
        end
      end

      it 'cretes correct amount of products for Diet Set 4' do
        diet_set = diet.diet_sets.find_by(name: 'Zestaw 4')
        expect(diet_set.products.count).to eq(26)
      end

      context 'when counting Products for meals in 4' do
        let(:diet_set) { diet.diet_sets.find_by(name: 'Zestaw 4') }

        it 'creates a product' do
          expect(diet_set.meals[0].products.count).to eq(3)
          expect(diet_set.meals[1].products.count).to eq(5)
          expect(diet_set.meals[2].products.count).to eq(12)
          expect(diet_set.meals[3].products.count).to eq(6)
        end
      end

      it 'cretes correct amount of products for Diet Set 5' do
        diet_set = diet.diet_sets.find_by(name: 'Zestaw 5')
        expect(diet_set.products.count).to eq(23)
      end

      context 'when counting Products for meals in 5' do
        let(:diet_set) { diet.diet_sets.find_by(name: 'Zestaw 5') }

        it 'creates a product' do
          expect(diet_set.meals[0].products.count).to eq(6)
          expect(diet_set.meals[1].products.count).to eq(5)
          expect(diet_set.meals[2].products.count).to eq(7)
          expect(diet_set.meals[3].products.count).to eq(5)
        end
      end

      it 'cretes correct amount of products for Diet Set 6' do
        diet_set = diet.diet_sets.find_by(name: 'Zestaw 6')
        expect(diet_set.products.count).to eq(24)
      end

      context 'when counting Products for meals in 6' do
        let(:diet_set) { diet.diet_sets.find_by(name: 'Zestaw 6') }

        it 'creates a product' do
          expect(diet_set.meals[0].products.count).to eq(5)
          expect(diet_set.meals[1].products.count).to eq(2)
          expect(diet_set.meals[2].products.count).to eq(12)
          expect(diet_set.meals[3].products.count).to eq(5)
        end
      end

      it 'cretes correct amount of products for Diet Set 7' do
        diet_set = diet.diet_sets.find_by(name: 'Zestaw 7')
        expect(diet_set.products.count).to eq(26)
      end

      context 'when counting Products for meals in 7' do
        let(:diet_set) { diet.diet_sets.find_by(name: 'Zestaw 7') }

        it 'creates a product' do
          expect(diet_set.meals[0].products.count).to eq(4)
          expect(diet_set.meals[1].products.count).to eq(5)
          expect(diet_set.meals[2].products.count).to eq(11)
          expect(diet_set.meals[3].products.count).to eq(6)
        end
      end

      it 'cretes correct amount of products for Diet Set 8' do
        diet_set = diet.diet_sets.find_by(name: 'Zestaw 8')
        expect(diet_set.products.count).to eq(24)
      end

      context 'when counting Products for meals in 8' do
        let(:diet_set) { diet.diet_sets.find_by(name: 'Zestaw 8') }

        it 'creates a product' do
          expect(diet_set.meals[0].products.count).to eq(4)
          expect(diet_set.meals[1].products.count).to eq(4)
          expect(diet_set.meals[2].products.count).to eq(12)
          expect(diet_set.meals[3].products.count).to eq(4)
        end
      end

      it 'cretes correct amount of products for Diet Set 9' do
        diet_set = diet.diet_sets.find_by(name: 'Zestaw 9')
        expect(diet_set.products.count).to eq(22)
      end

      context 'when counting Products for meals in 9' do
        let(:diet_set) { diet.diet_sets.find_by(name: 'Zestaw 9') }

        it 'creates a product' do
          expect(diet_set.meals[0].products.count).to eq(5)
          expect(diet_set.meals[1].products.count).to eq(3)
          expect(diet_set.meals[2].products.count).to eq(9)
          expect(diet_set.meals[3].products.count).to eq(5)
        end
      end

      it 'cretes correct amount of products for Diet Set 10' do
        diet_set = diet.diet_sets.find_by(name: 'Zestaw 10')
        expect(diet_set.products.count).to eq(25)
      end

      context 'when counting Products for meals in 10' do
        let(:diet_set) { diet.diet_sets.find_by(name: 'Zestaw 10') }

        it 'creates a product' do
          expect(diet_set.meals[0].products.count).to eq(4)
          expect(diet_set.meals[1].products.count).to eq(6)
          expect(diet_set.meals[2].products.count).to eq(9)
          expect(diet_set.meals[3].products.count).to eq(6)
        end
      end

      it 'cretes correct amount of products for Diet Set 11' do
        diet_set = diet.diet_sets.find_by(name: 'Zestaw 11')
        expect(diet_set.products.count).to eq(26)
      end

      context 'when counting Products for meals in 11' do
        let(:diet_set) { diet.diet_sets.find_by(name: 'Zestaw 11') }

        it 'creates a product' do
          expect(diet_set.meals[0].products.count).to eq(3)
          expect(diet_set.meals[1].products.count).to eq(2)
          expect(diet_set.meals[2].products.count).to eq(13)
          expect(diet_set.meals[3].products.count).to eq(8)
        end
      end

      it 'cretes correct amount of products for Diet Set 12' do
        diet_set = diet.diet_sets.find_by(name: 'Zestaw 12')
        expect(diet_set.products.count).to eq(25)
      end

      context 'when counting Products for meals in 12' do
        let(:diet_set) { diet.diet_sets.find_by(name: 'Zestaw 12') }

        it 'creates a product' do
          expect(diet_set.meals[0].products.count).to eq(3)
          expect(diet_set.meals[1].products.count).to eq(5)
          expect(diet_set.meals[2].products.count).to eq(13)
          expect(diet_set.meals[3].products.count).to eq(4)
        end
      end

      it 'cretes correct amount of products for Diet Set 13' do
        diet_set = diet.diet_sets.find_by(name: 'Zestaw 13')
        expect(diet_set.products.count).to eq(24)
      end

      context 'when counting Products for meals in 13' do
        let(:diet_set) { diet.diet_sets.find_by(name: 'Zestaw 13') }

        it 'creates a product' do
          expect(diet_set.meals[0].products.count).to eq(7)
          expect(diet_set.meals[1].products.count).to eq(4)
          expect(diet_set.meals[2].products.count).to eq(8)
          expect(diet_set.meals[3].products.count).to eq(5)
        end
      end

      it 'cretes correct amount of products for Diet Set 14' do
        diet_set = diet.diet_sets.find_by(name: 'Zestaw 14')
        expect(diet_set.products.count).to eq(34)
      end

      context 'when counting Products for meals in 14' do
        let(:diet_set) { diet.diet_sets.find_by(name: 'Zestaw 14') }

        it 'creates a product' do
          expect(diet_set.meals[0].products.count).to eq(6)
          expect(diet_set.meals[1].products.count).to eq(3)
          expect(diet_set.meals[2].products.count).to eq(13)
          expect(diet_set.meals[3].products.count).to eq(12)
        end
      end
    end
  end
end
