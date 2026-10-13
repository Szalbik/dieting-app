# frozen_string_literal: true

# Nightly retention promised by the privacy policy: PDF blobs no diet points to any more (deleted
# diets/accounts from before purge_later, failed uploads) and login sessions older than 12 months.
# ponytail: Session rows are never touched after login, so created_at = "zalogowanie" in the policy.
class DataRetentionJob < ApplicationJob
  queue_as :default

  ORPHAN_GRACE = 1.day # an upload attaches within the request; older unattached blobs are leftovers
  SESSION_TTL = 12.months

  def perform
    ActiveStorage::Blob.unattached.where(created_at: ...ORPHAN_GRACE.ago).find_each(&:purge)
    Session.where(created_at: ...SESSION_TTL.ago).delete_all
  end
end
