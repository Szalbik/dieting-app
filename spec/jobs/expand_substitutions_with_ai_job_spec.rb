# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExpandSubstitutionsWithAiJob, type: :job do
  describe '#perform' do
    let(:user) { create(:user) }
    let(:diet) { create(:diet, user: user) }
    let(:diet_set) { create(:diet_set, diet: diet) }
    let(:meal) { create(:meal, diet_set: diet_set) }

    before do
      create(:product, meal: meal, diet_set: diet_set, name: 'Bułka grahamka')
      create(:product, meal: meal, diet_set: diet_set, name: 'Chleb żytni')
      create(:product_substitution, user: user, source_product: 'Bułka grahamka', replacement_product: 'Chleb razowy')
    end

    it 'creates new substitutions from AI suggestions above confidence threshold' do
      allow(Chat::SubstitutionExpanderService).to receive(:new).and_return(
        double(
          call: [
            {
              'source_product' => 'Bułka grahamka',
              'replacements' => [
                { 'name' => 'Chleb żytni', 'confidence' => 0.91 },
                { 'name' => 'Woda', 'confidence' => 0.4 }
              ]
            }
          ]
        )
      )
      allow(MatchSubstitutionsToProductsJob).to receive(:perform_later)

      described_class.perform_now(user.id)

      expect(
        user.product_substitutions.exists?(source_product: 'Bułka grahamka', replacement_product: 'Chleb żytni')
      ).to be(true)
      expect(
        user.product_substitutions.exists?(source_product: 'Bułka grahamka', replacement_product: 'Woda')
      ).to be(false)
      expect(MatchSubstitutionsToProductsJob).to have_received(:perform_later).with(user.id)
    end
  end
end
