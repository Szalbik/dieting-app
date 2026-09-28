# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Shopping cart items', type: :request do
  let(:user) { create(:user, password: 'password123', password_confirmation: 'password123') }
  let(:diet) { create(:diet, user: user) }
  let(:diet_set) { create(:diet_set, diet: diet) }
  let(:meal) { create(:meal, diet_set: diet_set) }
  let(:product) { create(:product, meal: meal, name: 'Mleko 2%') }
  let(:cart) { user.shopping_cart }
  let!(:items) do
    [
      create(:shopping_cart_item, shopping_cart: cart, product: product, meal_plan: create(:meal_plan, meal: meal)),
      create(:shopping_cart_item, shopping_cart: cart, product: product, meal_plan: create(:meal_plan, meal: meal))
    ]
  end

  def login
    post session_path, params: { email_address: user.email_address, password: 'password123' }
  end

  def bought_flags
    items.map { |item| item.reload.bought }
  end

  describe 'PATCH /shopping_cart_items/:product_id/toggle_bought' do
    before { login }

    it 'flips the whole product group when no target value is given' do
      patch toggle_bought_shopping_cart_item_path(product)
      expect(bought_flags).to eq([true, true])

      patch toggle_bought_shopping_cart_item_path(product)
      expect(bought_flags).to eq([false, false])
    end

    it 'sets the group to bought and stays bought when replayed' do
      patch toggle_bought_shopping_cart_item_path(product), params: { bought: 'true' }
      expect(bought_flags).to eq([true, true])

      patch toggle_bought_shopping_cart_item_path(product), params: { bought: 'true' }
      expect(bought_flags).to eq([true, true])
    end

    it 'unsets a bought group when the target value is false' do
      items.each { |item| item.update!(bought: true) }

      patch toggle_bought_shopping_cart_item_path(product), params: { bought: 'false' }
      expect(bought_flags).to eq([false, false])
    end

    it 'treats a blank target value as a plain flip' do
      patch toggle_bought_shopping_cart_item_path(product), params: { bought: '' }
      expect(bought_flags).to eq([true, true])
    end

    it 'redirects to the cart for HTML requests' do
      patch toggle_bought_shopping_cart_item_path(product), params: { bought: 'true' }
      expect(response).to redirect_to(shopping_cart_path)
    end
  end

  describe 'PATCH /shopping_cart_items/:product_id/move' do
    let(:other) { create(:category, name: 'Inne') }

    before { login }

    it 'moves the product group to the chosen category and re-renders the cart' do
      patch move_shopping_cart_item_path(product), params: { category_id: other.id }, as: :turbo_stream

      expect(product.reload.product_category).to have_attributes(category_id: other.id, state: false)
      expect(response.body).to include('turbo-stream action="replace" target="shopping_cart"')
    end

    it 'ignores an unknown category' do
      expect do
        patch move_shopping_cart_item_path(product), params: { category_id: 0 }, as: :turbo_stream
      end.not_to(change { product.reload.product_category&.attributes })
      expect(response).to have_http_status(:ok)
    end

    it 'ignores a product outside the user\'s cart' do
      stranger = create(:product, meal: create(:meal, diet_set: create(:diet_set, diet: create(:diet))), name: 'Obcy')

      expect do
        patch move_shopping_cart_item_path(stranger), params: { category_id: other.id }, as: :turbo_stream
      end.not_to(change { stranger.reload.product_category&.attributes })
    end
  end
end
