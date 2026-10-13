# frozen_string_literal: true

ActiveAdmin.register User do
  menu priority: 2, label: 'Users'

  actions :index, :show, :destroy
  # Batch "Delete selected" would skip the self-delete guard, and its wrapping form swallows the row delete forms.
  config.batch_actions = false
  # The default "Delete User" action item is a data-method link, dead without rails-ujs; delete lives on the index.
  config.remove_action_item(:destroy)

  filter :email_address
  filter :admin
  filter :subscription, as: :select, collection: -> { User.subscriptions.keys.map { |s| [s.humanize, s] } }
  filter :created_at

  index do
    id_column
    column :email_address
    column :first_name
    column :admin
    column(:subscription) { |user| status_tag user.subscription }
    column(:diets) { |user| user.diets.size }
    column :created_at
    actions defaults: false do |user|
      item 'View', admin_user_path(user), class: 'member_link'
      text_node ' '
      # A real form: this panel ships no rails-ujs, so data-method links would just GET the show page.
      text_node helpers.button_to('Delete', admin_user_path(user),
                                  method: :delete, class: 'member_link',
                                  form: { class: 'inline', data: { confirm: "Delete #{user.email_address} and all their data?" } })
    end
  end

  show do
    attributes_table do
      row :id
      row :email_address
      row :first_name
      row :admin
      row(:subscription) { |user| status_tag user.subscription }
      row :subscription_end_date
      row(:diets) { |user| user.diets.count }
      row(:recipes) { |user| user.recipes.count }
      row :created_at
    end
  end

  controller do
    def scoped_collection
      super.includes(:diets)
    end

    def destroy
      user = resource

      if user == active_admin_current_user
        redirect_to admin_users_path, alert: 'You cannot delete your own account.'
      elsif user.destroy
        redirect_to admin_users_path, notice: "User #{user.email_address} was deleted."
      else
        redirect_to admin_users_path, alert: user.errors.full_messages.to_sentence
      end
    end
  end
end
