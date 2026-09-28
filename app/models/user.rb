# frozen_string_literal: true

class User < ApplicationRecord
  enum :subscription, { inactive: 0, active: 1, lifetime: 2 }, prefix: true

  AI_QUOTA_LIMITS = { free: 1, pro: 3 }.freeze

  after_create -> (first_name) { email_address.split('@').first }
  after_create :create_owned_shopping_cart

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

  has_many :diets, dependent: :nullify
  has_many :recipes, dependent: :destroy
  has_many :canonical_products, dependent: :destroy
  has_many :product_substitutions, dependent: :destroy
  has_many :meal_plan_product_substitutions, dependent: :destroy
  has_many :substitution_product_matches, dependent: :destroy
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

  # nil means unlimited (lifetime plan)
  def ai_quota_limit
    return nil if subscription_lifetime?

    subscribed? ? AI_QUOTA_LIMITS.fetch(:pro) : AI_QUOTA_LIMITS.fetch(:free)
  end

  def ai_quota_available?
    limit = ai_quota_limit
    return true if limit.nil?

    reset_ai_quota_period_if_stale!
    ai_quota_used_count < limit
  end

  def consume_ai_quota!
    return if subscription_lifetime?

    reset_ai_quota_period_if_stale!
    increment!(:ai_quota_used_count)
  end

  # Inverse of consume_ai_quota! — called when the enqueued AI job fails, so a
  # free user isn't locked out for the month by our parsing error.
  def refund_ai_quota!
    return if subscription_lifetime? || ai_quota_used_count.to_i <= 0

    decrement!(:ai_quota_used_count)
  end

  def stripe_customer
    return Stripe::Customer.retrieve(stripe_customer_id) if stripe_customer_id?

    customer = Stripe::Customer.create(email: email_address)
    update_column(:stripe_customer_id, customer.id)
    customer
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
end
