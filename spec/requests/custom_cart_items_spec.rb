# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Custom cart items', type: :request do
  let(:user) { create(:user, password: 'password123', password_confirmation: 'password123') }

  def login
    post session_path, params: { email_address: user.email_address, password: 'password123' }
  end

  describe 'POST /custom_cart_items' do
    it 'redirects when not authenticated' do
      post custom_cart_items_path, params: { custom_cart_item: { name: 'Mleko', quantity: 1, unit: 'l' } }
      expect(response).to redirect_to(new_session_path)
    end

    it 'creates an item and redirects to the cart' do
      login
      expect do
        post custom_cart_items_path, params: { custom_cart_item: { name: 'Mleko', quantity: 2, unit: 'l' } }
      end.to change(CustomCartItem, :count).by(1)

      expect(response).to redirect_to(shopping_cart_path)
      expect(CustomCartItem.last.name).to eq('Mleko')
    end
  end

  describe 'DELETE /custom_cart_items/:id' do
    it 'removes the item from the current user cart' do
      login
      cart = user.shopping_cart
      item = cart.custom_cart_items.create!(name: 'Chleb', quantity: 1, unit: 'szt')

      expect do
        delete custom_cart_item_path(item)
      end.to change(CustomCartItem, :count).by(-1)

      expect(response).to redirect_to(shopping_cart_path)
    end
  end
end
