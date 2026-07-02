# frozen_string_literal: true

class ReworkAiQuotaAndLifetimePlan < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :free_ai_op_used_at, :datetime
    add_column :users, :ai_quota_used_count, :integer, default: 0, null: false
    add_column :users, :ai_quota_period_started_at, :datetime
  end
end
