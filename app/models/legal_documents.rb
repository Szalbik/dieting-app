# frozen_string_literal: true

# Single source of the legal documents' version (Regulamin, Polityka prywatności, Polityka cookies).
# Recorded with terms acceptance at sign-up and shown in each document's header.
# EFFECTIVE_ON is when the version binds accounts created before it — set it to the day the
# change-notice mail goes out (legal:notify_terms_change) + 14 days (Regulamin §10 ust. 3).
module LegalDocuments
  VERSION = '2026-10-13'
  EFFECTIVE_ON = Date.new(2026, 10, 27)

  # Mails every account that accepted an older version (or none) about VERSION, once; returns the count.
  def self.notify_change!
    if EFFECTIVE_ON < Date.current + 14
      raise ArgumentError, "EFFECTIVE_ON (#{EFFECTIVE_ON}) must be at least 14 days ahead — bump it and redeploy first"
    end

    User.find_each.count do |user|
      next false if user.consents.values_at('terms_version', 'terms_notice').include?(VERSION)

      LegalMailer.terms_change(user).deliver_later
      user.update_column(:consents, user.consents.merge('terms_notice' => VERSION)) # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
