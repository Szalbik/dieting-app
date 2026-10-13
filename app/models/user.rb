# frozen_string_literal: true

class User < ApplicationRecord
  enum :subscription, { inactive: 0, active: 1, lifetime: 2 }, prefix: true

  AI_QUOTA_LIMITS = { free: 1, pro: 20 }.freeze # free = lifetime total, pro = per month
  FREE_PLANNING_WINDOW = 3.days # free plan: plan days within today ± this

  after_create :create_owned_shopping_cart
  # Declared above the associations so they run (guard first) before dependent: :destroy deletes the owned cart.
  # No prepend: true — it would reverse the pair and release carts before the guard.
  before_destroy :ensure_no_active_subscription, :release_shopping_carts

  belongs_to :active_shopping_cart, class_name: 'ShoppingCart', optional: true, inverse_of: :active_users
  has_one :owned_shopping_cart, class_name: 'ShoppingCart', dependent: :destroy, inverse_of: :user
  has_many :sent_shopping_cart_invitations,
           class_name: 'ShoppingCartInvitation',
           foreign_key: :inviter_id,
           dependent: :destroy,
           inverse_of: :inviter
  has_many :received_shopping_cart_invitations,
           class_name: 'ShoppingCartInvitation',
           foreign_key: :invitee_id,
           dependent: :destroy,
           inverse_of: :invitee

  has_many :diets, dependent: :destroy
  has_many :recipes, dependent: :destroy
  has_many :canonical_products, dependent: :destroy
  has_many :product_substitutions, dependent: :destroy
  has_many :meal_plan_product_substitutions, dependent: :destroy
  has_many :substitution_product_matches, dependent: :destroy
  has_many :product_name_suggestions, dependent: :destroy
  has_many :diet_set_plans, through: :diets
  has_many :products, through: :diets
  has_many :audit_logs, through: :diets

  has_secure_password
  has_many :sessions, dependent: :destroy

  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true
  validates :password, length: { minimum: 6 }, if: -> { new_record? || changes[:password_digest] }
  validates :password, confirmation: true, if: -> { new_record? || changes[:password_digest] }
  validates :password_confirmation, presence: true, if: -> { new_record? || changes[:password_digest] }

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # Admin panel filters only; never expose password_digest, consents or Stripe ids.
  def self.ransackable_attributes(_auth_object = nil)
    %w[admin created_at email_address first_name id subscription]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  # scope :active_diets, -> { diets.where(active: true) }

  def diet_history_by_date
    audit_logs.order(created_at: :desc).group_by(&:date)
  end

  def admin?
    admin
  end

  def active_diets
    diets.active
  end

  def active_diet_set_ids
    active_diets.joins(:diet_sets).pluck('diet_sets.id')
  end

  def active_products
    products.where(diet_set_id: active_diet_set_ids)
  end

  def shopping_cart
    active_shopping_cart || owned_shopping_cart
  end

  def accepted_shopping_cart_invitation
    ShoppingCartInvitation.accepted.involving(self).order(accepted_at: :desc, updated_at: :desc).first
  end

  def sharing_shopping_cart?
    accepted_shopping_cart_invitation.present?
  end

  def shopping_cart_partner
    accepted_shopping_cart_invitation&.other_user_for(self)
  end

  def shopping_cart_members
    invitation = accepted_shopping_cart_invitation
    return [self] unless invitation

    [invitation.inviter, invitation.invitee]
  end

  def subscribed?
    subscription_active? || subscription_lifetime? || subscription_end_date&.future?
  end

  def unlimited_planning?
    admin? || subscribed?
  end

  # Days shown in the plan date strip.
  def planning_range
    window = unlimited_planning? ? 1.month : FREE_PLANNING_WINDOW
    (Date.current - window)..(Date.current + window)
  end

  # Free plan is limited to today ± FREE_PLANNING_WINDOW; subscribers and admins can open any day.
  def plannable_date?(day)
    unlimited_planning? || planning_range.cover?(day)
  end

  # Free: lifetime total (never resets). Pro: per calendar month. Lifetime plan: unlimited.
  def ai_quota_available?
    return true if subscription_lifetime?
    return ai_free_used_count < AI_QUOTA_LIMITS.fetch(:free) unless subscribed?

    reset_ai_quota_period_if_stale!
    ai_quota_used_count < AI_QUOTA_LIMITS.fetch(:pro)
  end

  def consume_ai_quota!
    return if subscription_lifetime?
    return increment!(:ai_free_used_count) unless subscribed?

    reset_ai_quota_period_if_stale!
    increment!(:ai_quota_used_count)
  end

  # Inverse of consume_ai_quota! — called when the enqueued AI job fails, so a
  # user isn't charged a parse for our parsing error.
  def refund_ai_quota!
    return if subscription_lifetime?

    column = subscribed? ? :ai_quota_used_count : :ai_free_used_count
    decrement!(column) if self[column].to_i.positive?
  end

  def ai_free_remaining
    [AI_QUOTA_LIMITS.fetch(:free) - ai_free_used_count, 0].max
  end

  def stripe_customer
    return Stripe::Customer.retrieve(stripe_customer_id) if stripe_customer_id?

    customer = Stripe::Customer.create(email: email_address)
    update_column(:stripe_customer_id, customer.id)
    customer
  end

  # consents: { 'terms' => '2026-10-13T09:00:00+02:00', 'parse_disclaimer' => ... } — key → acceptance time
  def consented?(key)
    consents.key?(key.to_s)
  end

  def record_consent(key)
    self.consents = consents.merge(key.to_s => Time.current.iso8601)
  end

  # Like increment! in consume_ai_quota!: skips validations so a legacy record can't 500 a request that already did its work.
  def record_consent!(key)
    update_column(:consents, record_consent(key)) # rubocop:disable Rails/SkipsModelValidations
  end

  private

  def reset_ai_quota_period_if_stale!
    return if ai_quota_period_started_at.present? && ai_quota_period_started_at >= Time.current.beginning_of_month

    update_columns(ai_quota_used_count: 0, ai_quota_period_started_at: Time.current.beginning_of_month)
  end

  def create_owned_shopping_cart
    cart = ShoppingCart.create!(user: self)
    update_column(:active_shopping_cart_id, cart.id)
  end

  def ensure_no_active_subscription
    return unless subscription_active?

    errors.add(:base, 'Użytkownik ma aktywną subskrypcję — najpierw anuluj ją w Stripe.')
    throw :abort
  end

  # Un-share accepted carts so partners fall back to their own cart, then drop our pointer
  # to the owned cart that dependent: :destroy is about to delete.
  def release_shopping_carts
    ShoppingCartInvitation.accepted.involving(self).find_each do |invitation|
      ShoppingCartSharingService.new(invitation).revoke!(actor: self)
    end
    # Any pointer left without an accepted invite would still block the cart delete.
    User.where(active_shopping_cart_id: owned_shopping_cart&.id).where.not(id: id).find_each do |other|
      other.update_column(:active_shopping_cart_id, other.owned_shopping_cart&.id)
    end
    update_column(:active_shopping_cart_id, nil)
  end
end
