# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RemoveShoppingCartItemsJob, type: :job do
  let(:user) { create(:user) }
  let(:shopping_cart) { user.shopping_cart }
  let(:product) { create(:product) }
  let(:shopping_cart_item) { create(:shopping_cart_item, shopping_cart: shopping_cart, product: product) }

  describe '#perform' do
    it 'removes shopping cart items from the backend' do
      item = shopping_cart_item
      item_ids = [item.id]

      expect do
        described_class.perform_now(item_ids, user.id)
      end.to change { ShoppingCartItem.count }.by(-1)

      # Check that the item no longer exists in the database
      expect(ShoppingCartItem.exists?(item.id)).to be false
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
