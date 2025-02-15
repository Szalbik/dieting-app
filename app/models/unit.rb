# frozen_string_literal: true

class Unit < ApplicationRecord
  has_many :products, dependent: :nullify
end
