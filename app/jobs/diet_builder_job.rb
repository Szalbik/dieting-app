# frozen_string_literal: true

class DietBuilderJob < ApplicationJob
  queue_as :default

  def perform(diet_id)
    diet = Diet.find(diet_id)

    diet.parse_pdf_content_with_chat!
    raise 'Parser nie znalazł posiłków w PDF.' if diet.parsed_json.blank?

    # PopulateDietFromJsonJob flips status to ready and enqueues classification.
    PopulateDietFromJsonJob.perform_later(diet.id)
  rescue => e
    if diet
      diet.update!(status: 'failed', generation_error: e.message)
      diet.user&.refund_ai_quota!
    end
    raise
  end
end
