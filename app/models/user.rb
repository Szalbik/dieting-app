# frozen_string_literal: true

class User < ApplicationRecord
  after_create -> (first_name) { email_address.split('@').first }

  has_many :diets, dependent: :nullify
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
end
