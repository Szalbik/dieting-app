# frozen_string_literal: true

class User < ApplicationRecord
  after_create -> (first_name) { email.split('@').first }

  has_many :diets, dependent: :nullify
  has_many :products, through: :diets

  has_secure_password

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true
  normalizes :email, with: -> email { email.strip.downcase }

  # scope :active_diets, -> { diets.where(active: true) }

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
