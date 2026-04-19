# frozen_string_literal: true
ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    columns do
      column do
        panel 'Dietitian beta applications' do
          para "Pending applications: #{DietitianWaitlistEntry.pending.count}"
          para "Approved applications: #{DietitianWaitlistEntry.approved.count}"
          para do
            link_to 'Open waitlist', admin_dietitian_waitlist_entries_path
          end
        end
      end

      column do
        panel 'Most recent applications' do
          table_for DietitianWaitlistEntry.order(created_at: :desc).limit(5) do
            column(:first_name)
            column(:company_name)
            column(:status) { |entry| status_tag entry.status }
            column(:created_at)
          end
        end
      end
    end
  end # content
end
