# frozen_string_literal: true

class DietitianWaitlistEntry < ApplicationRecord
  enum :status, {
    pending: 0,
    demo_scheduled: 1,
    demo_completed: 2,
    approved: 3,
    rejected: 4
  }, default: :pending

  normalizes :email_address, with: ->(email) { email.strip.downcase }

  validates :first_name, :company_name, presence: true
  validates :email_address,
            presence: true,
            format: { with: URI::MailTo::EMAIL_REGEXP },
            uniqueness: { case_sensitive: false }

  before_save :populate_status_timestamps, if: :will_save_change_to_status?

  def self.ransackable_attributes(_auth_object = nil)
    %w[company_name created_at email_address first_name id notes status demo_called_at approved_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  private

  def populate_status_timestamps
    self.demo_called_at ||= Time.current if demo_completed?
    self.approved_at ||= Time.current if approved?
  end
end
