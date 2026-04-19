# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Product categories', type: :request do
  def login_as(user, password: 'password123')
    post session_path, params: { email_address: user.email_address, password: password }
  end

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return('')
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return('')
  end

  let(:password) { 'password123' }
  let(:admin) { create(:user, admin: true, password: password, password_confirmation: password) }
  let(:user) { create(:user, admin: false, password: password, password_confirmation: password) }

  describe 'GET /product_categories' do
    it 'blocks access for non-admin users' do
      login_as(user, password: password)

      get product_categories_path

      expect(response).to redirect_to(root_path)
    end

    it 'shows only pending products without confirmed counterparts and groups duplicates' do
      login_as(admin, password: password)

      category = create(:category, name: 'Nabial')

      ProductCategory.create!(product: Product.create!(name: 'Mleko'), category: category, state: false)
      ProductCategory.create!(product: Product.create!(name: 'mleko'), category: category, state: true)

      ProductCategory.create!(product: Product.create!(name: 'Ryż'), category: category, state: false)
      ProductCategory.create!(product: Product.create!(name: 'RYŻ'), category: category, state: false)

      get product_categories_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to match(/Ryż|RYŻ/)
      expect(response.body).to include('Powtórzenia:')
      expect(response.body).not_to include('Mleko')
    end

    it 'shows uncategorized products that have no product_categories yet' do
      login_as(admin, password: password)

      Product.create!(name: 'Marchew')
      Product.create!(name: 'MARCHEW')

      get product_categories_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to match(/Marchew|MARCHEW/)
      expect(response.body).to include('Powtórzenia:')
    end

    it 'paginates classification rows' do
      login_as(admin, password: password)

      21.times do |idx|
        Product.create!(name: format('Produkt %03d', idx))
      end

      get product_categories_path(page: 2)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Strona 2 z 2')
      expect(response.body).to include('Produkt 020')
      expect(response.body).not_to include('Produkt 000')
    end
  end

  describe 'PATCH /product_categories/:id' do
    it 'updates all exact same-name products and creates missing categories (case-insensitive)' do
      login_as(admin, password: password)

      old_category = create(:category, name: 'Orzechy')
      new_category = create(:category, name: 'Warzywa')

      target_1 = ProductCategory.create!(product: Product.create!(name: 'Pieprz'), category: old_category, state: false)
      target_2 = ProductCategory.create!(product: Product.create!(name: 'PIEPRZ'), category: old_category, state: false)
      uncategorized_product = Product.create!(name: 'Pieprz')
      other = ProductCategory.create!(product: Product.create!(name: 'Pieprz cayenne'), category: old_category,
                                      state: false)

      patch product_category_path(target_1), params: { product_category: { category_id: new_category.id } }

      expect(response).to redirect_to(product_categories_path)

      expect(target_1.reload.category).to eq(new_category)
      expect(target_1.state).to be(true)

      expect(target_2.reload.category).to eq(new_category)
      expect(target_2.state).to be(true)

      expect(uncategorized_product.reload.category).to eq(new_category)
      expect(uncategorized_product.product_category.state).to be(true)

      expect(other.reload.category).to eq(old_category)
      expect(other.state).to be(false)
    end

    it 'creates categories for all exact same-name uncategorized products' do
      login_as(admin, password: password)

      new_category = create(:category, name: 'Warzywa')
      first_product = Product.create!(name: 'Marchew')
      second_product = Product.create!(name: 'MARCHEW')

      patch product_category_path(first_product.id), params: {
        product_name: 'Marchew',
        product_category: { category_id: new_category.id }
      }

      expect(response).to redirect_to(product_categories_path)
      expect(first_product.reload.category).to eq(new_category)
      expect(second_product.reload.category).to eq(new_category)
      expect(first_product.product_category.state).to be(true)
      expect(second_product.product_category.state).to be(true)
    end

    it 'keeps the current page after updating a category' do
      login_as(admin, password: password)

      category = create(:category, name: 'Warzywa')
      product = Product.create!(name: 'Marchew')

      patch product_category_path(product.id), params: {
        page: 3,
        product_name: 'Marchew',
        product_category: { category_id: category.id }
      }

      expect(response).to redirect_to(product_categories_path(page: 3))
    end
  end
end
