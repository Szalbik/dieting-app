class CreateAuditLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :audit_logs do |t|
      t.references :trackable, polymorphic: true, null: false
      t.string :action
      t.text :description

      t.timestamps
    end
  end
end
