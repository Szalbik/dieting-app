# frozen_string_literal: true

class AuditLog < ApplicationRecord
  belongs_to :trackable, polymorphic: true

  def date
    created_at.to_date
  end
end
