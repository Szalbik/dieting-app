# frozen_string_literal: true

class ShoppingCartInvitationsController < ApplicationController
  def create
    invitee = User.find_by(email_address: params[:email_address].to_s.strip.downcase)

    unless invitee
      redirect_to profile_path, alert: 'Nie znaleziono uzytkownika o podanym adresie e-mail.'
      return
    end

    invitation = Current.user.sent_shopping_cart_invitations.new(invitee: invitee)

    if invitation.save
      redirect_to profile_path, notice: 'Zaproszenie do wspolnej listy zakupow zostalo wyslane.'
    else
      redirect_to profile_path, alert: invitation.errors.full_messages.to_sentence
    end
  end

  def accept
    invitation = Current.user.received_shopping_cart_invitations.find(params[:id])
    invitation.accept!
    redirect_to profile_path, notice: 'Wspolna lista zakupow zostala polaczona.'
  rescue ActiveRecord::RecordInvalid => e
    redirect_to profile_path, alert: e.record.errors.full_messages.to_sentence
  end

  def reject
    invitation = Current.user.received_shopping_cart_invitations.find(params[:id])

    if invitation.can_be_rejected_by?(Current.user)
      invitation.reject!
      redirect_to profile_path, notice: 'Zaproszenie zostalo odrzucone.'
    else
      redirect_to profile_path, alert: 'Nie mozna odrzucic tego zaproszenia.'
    end
  end

  def revoke
    invitation = ShoppingCartInvitation.involving(Current.user).find(params[:id])

    if invitation.can_be_revoked_by?(Current.user)
      invitation.revoke!(actor: Current.user)
      redirect_to profile_path, notice: 'Polaczenie listy zakupow zostalo zakonczone.'
    else
      redirect_to profile_path, alert: 'Nie mozna odwolac tego zaproszenia.'
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to profile_path, alert: e.record.errors.full_messages.to_sentence
  end
end
