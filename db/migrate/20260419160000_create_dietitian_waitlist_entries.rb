# frozen_string_literal: true

class CreateDietitianWaitlistEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :dietitian_waitlist_entries do |t|
      t.string :first_name, null: false
      t.string :email_address, null: false
      t.string :company_name, null: false
      t.integer :status, null: false, default: 0
      t.text :notes
      t.datetime :demo_called_at
      t.datetime :approved_at

      t.timestamps
    end

    add_index :dietitian_waitlist_entries, :email_address, unique: true
    add_index :dietitian_waitlist_entries, :status
    add_index :dietitian_waitlist_entries, :created_at
  end
end
