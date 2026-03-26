# frozen_string_literal: true

class ShoppingCartInvitation < ApplicationRecord
  enum :status, {
    pending: 0,
    accepted: 1,
    rejected: 2,
    revoked: 3,
  }

  belongs_to :inviter, class_name: 'User'
  belongs_to :invitee, class_name: 'User'

  validate :cannot_invite_yourself
  validate :participants_are_available, on: :create
  validate :pending_invitation_for_pair_is_unique, on: :create

  scope :involving, lambda { |user|
    where(inviter: user).or(where(invitee: user))
  }

  def accept!
    ShoppingCartSharingService.new(self).accept!
  end

  def reject!
    update!(status: :rejected, responded_at: Time.current)
  end

  def revoke!(actor:)
    ShoppingCartSharingService.new(self).revoke!(actor:)
  end

  def other_user_for(user)
    inviter_id == user.id ? invitee : inviter
  end

  def can_be_accepted_by?(user)
    pending? && invitee_id == user.id
  end

  def can_be_rejected_by?(user)
    pending? && invitee_id == user.id
  end

  def can_be_revoked_by?(user)
    return inviter_id == user.id if pending?
    accepted? && [inviter_id, invitee_id].include?(user.id)
  end

  private

  def cannot_invite_yourself
    return if inviter_id != invitee_id

    errors.add(:invitee, 'nie moze byc tym samym uzytkownikiem')
  end

  def participants_are_available
    participants = [inviter, invitee].compact
    return if participants.none?(&:sharing_shopping_cart?)

    errors.add(:base, 'Jedna z tych osob ma juz aktywna wspoldzielona liste zakupow.')
  end

  def pending_invitation_for_pair_is_unique
    return unless self.class.pending
      .where(inviter: [inviter, invitee], invitee: [inviter, invitee])
      .where.not(id: id)
      .exists?

    errors.add(:base, 'Zaproszenie dla tej pary juz oczekuje na decyzje.')
  end
end
