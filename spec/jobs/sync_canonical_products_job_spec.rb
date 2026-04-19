# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncCanonicalProductsJob, type: :job do
  describe '#perform' do
    it 'backfills existing product variants into one canonical product with aliases' do
      user = create(:user)
      diet = create(:diet, user: user)
      diet_set = create(:diet_set, diet: diet)
      meal = create(:meal, diet_set: diet_set)

      jajka = create(:product, meal: meal, diet_set: diet_set)
      jajka.update_columns(name: 'jajka', canonical_product_id: nil)

      jajko = create(:product, meal: meal, diet_set: diet_set)
      jajko.update_columns(name: 'Jajko', canonical_product_id: nil)

      jaja = create(:product, meal: meal, diet_set: diet_set)
      jaja.update_columns(name: 'jaja', canonical_product_id: nil)

      described_class.perform_now(user.id)

      canonical_ids = [jajka, jajko, jaja].map { |product| product.reload.canonical_product_id }.uniq

      expect(canonical_ids.size).to eq(1)
      canonical = jajko.reload.canonical_product
      expect(canonical.name).to eq('Jajko')
      expect(canonical.canonical_product_aliases.pluck(:name)).to include('jajka', 'Jajko', 'jaja')
      expect(canonical.canonical_product_aliases.pluck(:stem_signature).uniq).to eq(['jajko'])
    end
  end
end
