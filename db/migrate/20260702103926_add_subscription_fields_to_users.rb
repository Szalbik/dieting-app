# frozen_string_literal: true

class AddSubscriptionFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :stripe_customer_id, :string
    add_index :users, :stripe_customer_id, unique: true
    add_column :users, :subscription, :integer, default: 0, null: false
    add_column :users, :subscription_end_date, :datetime
    add_column :users, :free_ai_op_used_at, :datetime
  end
end
