# frozen_string_literal: true

class AddConsents < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :consents, :json, default: {}, null: false
    add_column :diets, :pii_confirmed_at, :datetime
  end
end
