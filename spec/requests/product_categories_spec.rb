# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Product categories', type: :request do
  def login_as(user, password: 'password123')
    post session_path, params: { email_address: user.email_address, password: password }
  end

  describe 'GET /product_categories' do
    let(:password) { 'password123' }
    let(:admin) { create(:user, admin: true, password: password, password_confirmation: password) }
    let(:user) { create(:user, admin: false, password: password, password_confirmation: password) }

    it 'blocks access for non-admin users' do
      login_as(user, password: password)

      get product_categories_path

      expect(response).to redirect_to(root_path)
    end

    it 'shows only pending products without confirmed counterparts' do
      login_as(admin, password: password)

      category = create(:category, name: 'Nabial')

      hidden_product = Product.create!(name: 'Mleko')
      ProductCategory.create!(product: hidden_product, category: category, state: false)
      ProductCategory.create!(product: Product.create!(name: 'mleko'), category: category, state: true)

      visible_product = Product.create!(name: 'Ryż')
      ProductCategory.create!(product: visible_product, category: category, state: false)

      get product_categories_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Ryż')
      expect(response.body).not_to include('Mleko')
    end
  end
end
