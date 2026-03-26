# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ShoppingCartItemsController, type: :controller do
  let(:user) { create(:user) }
  let(:diet) { create(:diet, user: user) }
  let(:diet_set) { create(:diet_set, diet: diet) }
  let(:meal) { create(:meal, diet_set: diet_set) }
  let(:diet_set_plan) { create(:diet_set_plan, diet_set: diet_set, diet: diet, date: Date.current) }
  let(:meal_plan) { create(:meal_plan, diet_set_plan: diet_set_plan, meal: meal, selected_for_cart: true) }
  let(:product) { create(:product, meal: meal, diet_set: diet_set) }
  let(:shopping_cart) { user.shopping_cart }
  let(:shopping_cart_item) { create(:shopping_cart_item, shopping_cart: shopping_cart, product: product, meal_plan: meal_plan) }

  before do
    # Mock the authentication system
    allow(controller).to receive(:require_authentication).and_return(true)
    allow(controller).to receive(:resume_session).and_return(true)

    # Mock Current.user
    allow(Current).to receive(:user).and_return(user)
    allow(Current).to receive(:session).and_return(double(user: user))
  end

  describe 'DELETE #destroy' do
    before do
      shopping_cart_item
    end

    it 'schedules a background job to remove items' do
      expect do
        delete :destroy, params: { id: product.id }
      end.to have_enqueued_job(RemoveShoppingCartItemsJob).with([shopping_cart_item.id], user.id)
    end

    it 'stores removal record in session for undo' do
      delete :destroy, params: { id: product.id }

      expect(session[:removed_items]).to be_present
      expect(session[:removed_items].last[:item_ids]).to eq([shopping_cart_item.id])
      expect(session[:removed_items].last[:product_name]).to eq(product.shopping_cart_group_name)
    end

    it 'sets flash message' do
      delete :destroy, params: { id: product.id }

      expect(flash[:success]).to eq('Produkt został usunięty z koszyka. Możesz cofnąć operację w ciągu 30 minut.')
    end

    it 'removes items from shopping cart immediately' do
      delete :destroy, params: { id: product.id }

      expect(shopping_cart.shopping_cart_items.reload).to be_empty
    end

    it 'removes all items sharing the same canonical product name' do
      canonical_product = create(:canonical_product, user: user, name: 'Jogurt naturalny')
      product.update_columns(name: 'Jogurt naturalny', canonical_product_id: canonical_product.id)

      other_product = create(:product, meal: meal, diet_set: diet_set)
      other_product.update_columns(name: 'Jogurt naturalny 2% tłuszczu', canonical_product_id: canonical_product.id)
      other_item = create(:shopping_cart_item,
                          shopping_cart: shopping_cart,
                          product: other_product,
                          meal_plan: meal_plan)

      delete :destroy, params: { id: product.id }

      expect(session[:removed_items].last[:item_ids]).to match_array([shopping_cart_item.id, other_item.id])
      expect(shopping_cart.shopping_cart_items.reload).to be_empty
    end
  end

  describe 'POST #undo' do
    let(:removal_record) do
      {
        item_ids: [shopping_cart_item.id],
        removed_at: Time.current.to_i,
        product_name: product.name,
        category_name: product.category&.name || 'Inne',
        items: [
          {
            product_id: product.id,
            quantity: shopping_cart_item.quantity,
            date: shopping_cart_item.date,
            meal_plan_id: shopping_cart_item.meal_plan_id
          }
        ]
      }
    end

    before do
      session[:removed_items] = [removal_record]
      allow(RemoveShoppingCartItemsJob).to receive(:cancel_scheduled_jobs)
      allow(shopping_cart.shopping_cart_items).to receive(:create!)
    end

    it 'restores items within time limit' do
      post :undo

      expect(RemoveShoppingCartItemsJob).to have_received(:cancel_scheduled_jobs).with([shopping_cart_item.id], user.id)
      expect(shopping_cart.shopping_cart_items).to have_received(:create!)
      expect(flash[:success]).to eq('Produkt został przywrócony do koszyka.')
    end

    it 'cancels scheduled background job' do
      post :undo

      expect(RemoveShoppingCartItemsJob).to have_received(:cancel_scheduled_jobs).with([shopping_cart_item.id], user.id)
    end

    it 'handles expired removal records' do
      expired_record = removal_record.merge(removed_at: (Time.current - 31.minutes).to_i)
      session[:removed_items] = [expired_record]

      post :undo

      expect(flash[:info]).to eq('No items to undo')
    end

    it 'handles no removal records' do
      session[:removed_items] = []

      post :undo

      expect(flash[:info]).to eq('No items to undo')
    end
  end
end
