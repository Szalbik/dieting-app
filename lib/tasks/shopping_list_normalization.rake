# frozen_string_literal: true

namespace :shopping_list do
  desc 'Backfill canonical shopping-list normalization for all users or a single USER_EMAIL'
  task backfill_product_normalization: :environment do
    users = if ENV['USER_EMAIL'].present?
              user = User.find_by(email_address: ENV['USER_EMAIL'])
              abort "Nie znaleziono użytkownika: #{ENV['USER_EMAIL']}" unless user

              [user]
            else
              User.order(:id).to_a
            end

    users.each do |user|
      SyncCanonicalProductsJob.perform_now(user.id)
      puts "Zsynchronizowano canonical products dla user##{user.id} #{user.email_address}"
    end
  end
end
