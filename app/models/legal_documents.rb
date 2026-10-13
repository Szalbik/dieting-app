# frozen_string_literal: true

# Single source of the legal documents' version (Regulamin, Polityka prywatności, Polityka cookies).
# Recorded with terms acceptance at sign-up and shown in each document's header.
# EFFECTIVE_ON is when the version binds accounts created before it — set it to the day the
# change-notice mail goes out (legal:notify_terms_change) + 14 days (Regulamin §10 ust. 3).
module LegalDocuments
  VERSION = '2026-10-13'
  EFFECTIVE_ON = Date.new(2026, 10, 27)
end
