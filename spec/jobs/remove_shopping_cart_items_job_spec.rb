# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RemoveShoppingCartItemsJob, type: :job do
  let(:user) { create(:user) }
  let(:shopping_cart) { user.shopping_cart }
  let(:product) { create(:product) }
  let(:shopping_cart_item) { create(:shopping_cart_item, shopping_cart: shopping_cart, product: product) }

  describe '#perform' do
    it 'hard-deletes soft-deleted shopping cart items' do
      item = shopping_cart_item
      item_ids = [item.id]
      item.destroy

      expect(ShoppingCartItem.only_deleted.where(id: item.id)).to exist

      described_class.perform_now(item_ids, user.id)

      expect(ShoppingCartItem.with_deleted.where(id: item.id)).not_to exist
    end

    it 'handles non-existent items gracefully' do
      expect do
        described_class.perform_now([999_999], user.id)
      end.not_to raise_error
    end

    it 'handles non-existent user gracefully' do
      expect do
        described_class.perform_now([1], 999_999)
      end.not_to raise_error
    end

    it 'handles empty item_ids array' do
      expect do
        described_class.perform_now([], user.id)
      end.not_to raise_error
    end
  end
end
