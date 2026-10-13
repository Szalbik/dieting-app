# frozen_string_literal: true

namespace :legal do
  desc 'Mail existing users about the new legal documents (set LegalDocuments::EFFECTIVE_ON = today + 14 first)'
  task notify_terms_change: :environment do
    puts "Queued #{LegalDocuments.notify_change!} change notices for version #{LegalDocuments::VERSION}."
  end
end
