# frozen_string_literal: true

class ShoppingCartSharingService
  def initialize(invitation)
    @invitation = invitation
  end

  def accept!
    raise ActiveRecord::RecordInvalid, invitation unless invitation.pending?

    ActiveRecord::Base.transaction do
      ensure_users_are_available!

      shared_cart = invitation.inviter.owned_shopping_cart
      merge_custom_items!(source: invitation.invitee.owned_shopping_cart, target: shared_cart)

      invitation.update!(
        status: :accepted,
        accepted_at: Time.current,
        responded_at: Time.current
      )

      invitation.inviter.update!(active_shopping_cart: shared_cart)
      invitation.invitee.update!(active_shopping_cart: shared_cart)

      ShoppingCartSyncService.new(
        shopping_cart: shared_cart,
        users: [invitation.inviter, invitation.invitee]
      ).call
    end
  end

  def revoke!(actor:)
    raise ActiveRecord::RecordInvalid, invitation unless invitation.can_be_revoked_by?(actor)

    ActiveRecord::Base.transaction do
      if invitation.accepted?
        shared_cart = invitation.inviter.owned_shopping_cart
        invitee_cart = invitation.invitee.owned_shopping_cart

        replace_custom_items!(source: shared_cart, target: invitee_cart)

        invitation.inviter.update!(active_shopping_cart: invitation.inviter.owned_shopping_cart)
        invitation.invitee.update!(active_shopping_cart: invitee_cart)

        invitation.update!(
          status: :revoked,
          revoked_at: Time.current,
          responded_at: Time.current
        )

        ShoppingCartSyncService.new(
          shopping_cart: invitation.inviter.owned_shopping_cart,
          users: invitation.inviter
        ).call
        ShoppingCartSyncService.new(
          shopping_cart: invitee_cart,
          users: invitation.invitee
        ).call
      else
        invitation.update!(
          status: :revoked,
          revoked_at: Time.current,
          responded_at: Time.current
        )
      end
    end
  end

  private

  attr_reader :invitation

  def ensure_users_are_available!
    participants = [invitation.inviter, invitation.invitee]
    return unless participants.any? do |user|
      user.sharing_shopping_cart? && user.accepted_shopping_cart_invitation != invitation
    end

    invitation.errors.add(:base, 'Jedna z tych osob ma juz aktywna wspoldzielona liste zakupow.')
    raise ActiveRecord::RecordInvalid, invitation
  end

  def merge_custom_items!(source:, target:)
    source.custom_cart_items.find_each do |item|
      target_item = target.custom_cart_items.find_or_initialize_by(
        name: item.name,
        unit: item.unit
      )
      target_item.quantity = target_item.quantity.to_i + item.quantity.to_i
      target_item.save!
    end
  end

  def replace_custom_items!(source:, target:)
    target.custom_cart_items.delete_all

    source.custom_cart_items.find_each do |item|
      target.custom_cart_items.create!(
        name: item.name,
        quantity: item.quantity,
        unit: item.unit
      )
    end
  end
end
