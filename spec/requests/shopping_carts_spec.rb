# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Shopping carts', type: :request do
  let(:user) { create(:user, password: 'password123', password_confirmation: 'password123') }

  def login
    post session_path, params: { email_address: user.email_address, password: 'password123' }
  end

  describe 'GET /shopping_cart' do
    it 'redirects when not authenticated' do
      get shopping_cart_path
      expect(response).to redirect_to(new_session_path)
    end

    it 'renders for the logged-in user' do
      login
      get shopping_cart_path
      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET /shopping_cart drag and drop markup' do
    let(:cart) { user.shopping_cart }
    let(:diet) { create(:diet, user: user) }
    let(:meal) { create(:meal, diet_set: create(:diet_set, diet: diet)) }
    let(:category_a) { create(:category, name: 'Nabiał') }
    let(:category_b) { create(:category, name: 'Pieczywo') }
    let(:plan) { create(:diet_set_plan, diet_set: meal.diet_set) }
    let!(:spare) { create(:category, name: 'Napoje') }
    let!(:unbought) { create(:product, meal: meal, name: 'Mleko 2%') }
    let!(:bought) { create(:product, meal: meal, name: 'Chleb') }

    before do
      create(:product_category, product: unbought, category: category_a)
      create(:product_category, product: bought, category: category_b)
      meal_plan = create(:meal_plan, meal: meal, diet_set_plan: plan)
      create(:shopping_cart_item, shopping_cart: cart, product: unbought, meal_plan: meal_plan)
      create(:shopping_cart_item, shopping_cart: cart, product: bought, bought: true, meal_plan: meal_plan)
      login
      get shopping_cart_path
    end

    let(:page) { Nokogiri::HTML(response.body) }

    it 'has no category select and marks only unbought rows as draggable' do
      expect(page.css('select[name=category_id]')).to be_empty
      expect(page.css("[data-move-url='#{move_shopping_cart_item_path(unbought)}']").size).to eq(1)
      expect(page.css("[data-move-url='#{move_shopping_cart_item_path(bought)}']")).to be_empty
    end

    it 'makes unbought category cards drop targets and lists only unused categories as tiles' do
      expect(page.css("#category_nabial[data-drop-category-id='#{category_a.id}']").size).to eq(1)
      expect(page.css('#category_pieczywo_bought[data-drop-category-id]')).to be_empty

      tiles = page.css('[data-cart-drag-target=tiles] [data-drop-category-id]')
      tile_ids = tiles.map { |n| n['data-drop-category-id'].to_i }
      expect(tile_ids).to include(category_b.id, spare.id)
      expect(tile_ids).not_to include(category_a.id)
    end
  end
end
