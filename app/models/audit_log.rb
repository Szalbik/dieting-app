# frozen_string_literal: true

class AuditLog < ApplicationRecord
  belongs_to :trackable, polymorphic: true
end
