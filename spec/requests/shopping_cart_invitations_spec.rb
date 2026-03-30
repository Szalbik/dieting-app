# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Shopping cart invitations', type: :request do
  let(:inviter) { create(:user, password: 'password123', password_confirmation: 'password123') }
  let(:invitee) { create(:user, password: 'password123', password_confirmation: 'password123') }

  def login(user)
    post session_path, params: { email_address: user.email_address, password: 'password123' }
  end

  describe 'POST /shopping_cart_invitations' do
    it 'redirects when not authenticated' do
      post shopping_cart_invitations_path, params: { email_address: invitee.email_address }
      expect(response).to redirect_to(new_session_path)
    end

    it 'creates a pending invitation for an existing user' do
      login(inviter)
      expect do
        post shopping_cart_invitations_path, params: { email_address: invitee.email_address }
      end.to change(ShoppingCartInvitation, :count).by(1)

      expect(response).to redirect_to(profile_path)
      invitation = ShoppingCartInvitation.last
      expect(invitation).to be_pending
      expect(invitation.inviter).to eq(inviter)
      expect(invitation.invitee).to eq(invitee)
    end

    it 'redirects with alert when the email is unknown' do
      login(inviter)
      post shopping_cart_invitations_path, params: { email_address: 'nobody@example.com' }
      expect(response).to redirect_to(profile_path)
      follow_redirect!
      expect(response.body).to include('Nie znaleziono uzytkownika')
    end
  end

  describe 'PATCH /shopping_cart_invitations/:id/accept' do
    let(:invitation) { create(:shopping_cart_invitation, inviter: inviter, invitee: invitee) }

    it 'lets the invitee accept' do
      login(invitee)
      patch accept_shopping_cart_invitation_path(invitation)
      expect(response).to redirect_to(profile_path)
      expect(invitation.reload).to be_accepted
    end
  end

  describe 'PATCH /shopping_cart_invitations/:id/reject' do
    let(:invitation) { create(:shopping_cart_invitation, inviter: inviter, invitee: invitee) }

    it 'lets the invitee reject' do
      login(invitee)
      patch reject_shopping_cart_invitation_path(invitation)
      expect(response).to redirect_to(profile_path)
      expect(invitation.reload).to be_rejected
    end
  end

  describe 'PATCH /shopping_cart_invitations/:id/revoke' do
    let(:invitation) { create(:shopping_cart_invitation, inviter: inviter, invitee: invitee) }

    it 'lets the inviter revoke a pending invitation' do
      login(inviter)
      patch revoke_shopping_cart_invitation_path(invitation)
      expect(response).to redirect_to(profile_path)
      expect(invitation.reload).to be_revoked
    end
  end
end
