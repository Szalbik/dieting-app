# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ShoppingCartItemsController, type: :controller do
  let(:user) { create(:user) }
  let(:product) { create(:product) }
  let(:shopping_cart) { user.shopping_cart }
  let(:shopping_cart_item) { create(:shopping_cart_item, shopping_cart: shopping_cart, product: product) }
  let(:items_relation) { double('ItemsRelation') }

  before do
    # Mock the authentication system
    allow(controller).to receive(:require_authentication).and_return(true)
    allow(controller).to receive(:resume_session).and_return(true)

    # Mock Current.user
    allow(Current).to receive(:user).and_return(user)
    allow(Current).to receive(:session).and_return(double(user: user))

    # Mock the shopping cart and items
    allow(user).to receive(:shopping_cart).and_return(shopping_cart)
    allow(user).to receive(:products).and_return(double(find: product))

    # Mock the items relation properly
    allow(shopping_cart).to receive(:shopping_cart_items).and_return(items_relation)
    allow(items_relation).to receive(:joins).and_return(items_relation)
    allow(items_relation).to receive(:where).and_return(items_relation)
    allow(items_relation).to receive(:pluck).and_return([shopping_cart_item.id])
    allow(items_relation).to receive(:destroy_all)
  end

  describe 'DELETE #destroy' do
    it 'schedules a background job to remove items' do
      expect do
        delete :destroy, params: { id: product.id }
      end.to have_enqueued_job(RemoveShoppingCartItemsJob).with([shopping_cart_item.id], user.id)
    end

    it 'stores removal record in session for undo' do
      delete :destroy, params: { id: product.id }

      expect(session[:removed_items]).to be_present
      expect(session[:removed_items].last[:item_ids]).to eq([shopping_cart_item.id])
      expect(session[:removed_items].last[:product_name]).to eq(product.name)
    end

    it 'sets flash message' do
      delete :destroy, params: { id: product.id }

      expect(flash[:success]).to eq('Produkt został usunięty z koszyka. Możesz cofnąć operację w ciągu 30 minut.')
    end

    it 'removes items from shopping cart immediately' do
      delete :destroy, params: { id: product.id }

      expect(items_relation).to have_received(:destroy_all)
    end
  end

  describe 'POST #undo' do
    let(:removal_record) do
      {
        item_ids: [shopping_cart_item.id],
        removed_at: Time.current.to_i,
        product_name: product.name,
        category_name: product.category&.name || 'Inne'
      }
    end

    before do
      session[:removed_items] = [removal_record]
      allow(RemoveShoppingCartItemsJob).to receive(:cancel_scheduled_jobs)
      allow(Current.user.products).to receive(:find_by).and_return(product)
      allow(shopping_cart.shopping_cart_items).to receive(:create!)
    end

    it 'restores items within time limit' do
      post :undo

      expect(RemoveShoppingCartItemsJob).to have_received(:cancel_scheduled_jobs).with([shopping_cart_item.id], user.id)
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

      expect(flash[:warning]).to eq('No items to undo or undo time limit expired')
    end

    it 'handles no removal records' do
      session[:removed_items] = []

      post :undo

      expect(flash[:info]).to eq('No items to undo')
    end
  end
end
