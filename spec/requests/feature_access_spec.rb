# frozen_string_literal: true

require 'rails_helper'

# Regular users (free or Pro) get diets, plan, shopping, substitutions and profile only;
# recipes and Todoist are admin-only.
RSpec.describe 'Feature access for non-admin users', type: :request do
  let(:user) { create(:user, password: 'password123', password_confirmation: 'password123') }

  before { post session_path, params: { email_address: user.email_address, password: 'password123' } }

  it 'redirects away from recipes and Todoist' do
    [recipes_path, new_recipe_path, todoist_projects_path, todoist_authorize_path].each do |path|
      get path
      expect(response).to redirect_to(root_path), "expected #{path} to be blocked"
    end
  end

  it 'keeps the core sections reachable and hides the recipes link' do
    [diets_path, diet_set_plans_path, shopping_cart_path, product_substitutions_path, profile_path].each do |path|
      get path
      expect(response).not_to redirect_to(root_path), "expected #{path} to be open"
    end
    expect(response.body).not_to include(recipes_path)
  end
end
