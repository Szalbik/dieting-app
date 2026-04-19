# frozen_string_literal: true

ActiveAdmin.register DietitianWaitlistEntry do
  menu priority: 1, label: 'Dietitian waitlist'

  actions :index, :show, :edit, :update
  permit_params :status, :notes

  filter :status, as: :select, collection: -> { DietitianWaitlistEntry.statuses.keys.map { |status| [status.humanize, status] } }
  filter :company_name
  filter :email_address
  filter :created_at

  scope :all, default: true
  scope :pending
  scope :demo_scheduled
  scope :demo_completed
  scope :approved
  scope :rejected

  index do
    selectable_column
    id_column
    column :first_name
    column :email_address
    column :company_name
    column(:status) { |entry| status_tag entry.status }
    column :created_at
    column :demo_called_at
    column :approved_at
    actions defaults: false do |entry|
      item 'View', admin_dietitian_waitlist_entry_path(entry), class: 'member_link'
      text_node ' '
      item 'Edit', edit_admin_dietitian_waitlist_entry_path(entry), class: 'member_link'
    end
  end

  show do
    attributes_table do
      row :id
      row :first_name
      row :email_address
      row :company_name
      row(:status) { |entry| status_tag entry.status }
      row :notes
      row :created_at
      row :updated_at
      row :demo_called_at
      row :approved_at
    end
  end

  form do |f|
    f.semantic_errors

    f.inputs 'Dietitian application' do
      f.input :first_name, input_html: { disabled: true }
      f.input :email_address, input_html: { disabled: true }
      f.input :company_name, input_html: { disabled: true }
      f.input :status, as: :select, collection: DietitianWaitlistEntry.statuses.keys.map { |status| [status.humanize, status] }
      f.input :notes
      f.input :demo_called_at, input_html: { disabled: true }
      f.input :approved_at, input_html: { disabled: true }
    end

    f.actions
  end
end
