# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin users', type: :request do
  let(:password) { 'password123' }
  let(:admin_user) { create(:user, :admin, password: password, password_confirmation: password) }
  let(:regular_user) { create(:user, password: password, password_confirmation: password) }

  def login(user)
    post session_path, params: { email_address: user.email_address, password: password }
  end

  describe 'GET /admin/users' do
    it 'redirects guests to sign in' do
      get admin_users_path

      expect(response).to redirect_to(new_session_path)
    end

    it 'redirects non-admin users away from the panel' do
      login(regular_user)

      get admin_users_path

      expect(response).to redirect_to(root_path)
    end

    it 'lists users for admins' do
      regular_user
      login(admin_user)

      get admin_users_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(regular_user.email_address)
    end

    it 'renders delete as a confirmed DELETE form (the panel has no rails-ujs)' do
      regular_user
      login(admin_user)

      get admin_users_path

      form = Nokogiri::HTML(response.body).at_css(%(form[action="#{admin_user_path(regular_user)}"]))
      expect(form&.at_css('input[name="_method"][value="delete"]')).to be_present
      expect(form['data-confirm']).to include(regular_user.email_address)
      expect(form.ancestors('form')).to be_empty # browsers drop nested forms
    end
  end

  it 'offers no batch actions (batch destroy would bypass the self-delete guard)' do
    login(admin_user)

    get admin_users_path

    expect(response.body).not_to include('batch_action')
  end

  it 'does not let a non-admin delete users' do
    target = create(:user)
    login(regular_user)

    expect { delete admin_user_path(target) }.not_to change(User, :count)
    expect(response).to redirect_to(root_path)
  end

  it 'has no data-method delete link on the show page (nothing runs it here)' do
    login(admin_user)

    get admin_user_path(regular_user)

    dead_link = Nokogiri::HTML(response.body).at_css(%(a[data-method="delete"][href="#{admin_user_path(regular_user)}"]))
    expect(dead_link).to be_nil
  end

  describe 'DELETE /admin/users/:id' do
    before { login(admin_user) }

    it 'deletes another user together with their diets' do
      create(:diet_set, diet: create(:diet, user: regular_user))

      expect { delete admin_user_path(regular_user) }.to change(User, :count).by(-1)
      expect(response).to redirect_to(admin_users_path)
      expect(flash[:notice]).to be_present
    end

    it 'refuses to delete the signed-in admin' do
      expect { delete admin_user_path(admin_user) }.not_to change(User, :count)
      expect(response).to redirect_to(admin_users_path)
      expect(flash[:alert]).to be_present
    end

    it 'refuses to delete a user with an active subscription and shows why' do
      regular_user.update!(subscription: :active)

      expect { delete admin_user_path(regular_user) }.not_to change(User, :count)
      expect(response).to redirect_to(admin_users_path)
      expect(flash[:alert]).to include('subskrypcj')
    end
  end
end
