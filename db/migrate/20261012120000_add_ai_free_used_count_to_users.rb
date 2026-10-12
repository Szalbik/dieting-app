# frozen_string_literal: true


class AddAiFreeUsedCountToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :ai_free_used_count, :integer, default: 0, null: false
  end
end
