# frozen_string_literal: true

class GenerateDietJob < ApplicationJob
  queue_as :default

  def perform(diet_id)
    diet = Diet.find(diet_id)
    days = Chat::DietGeneratorService.new(diet).call
    diet.update!(parsed_json: days)

    PopulateDietFromJsonJob.perform_later(diet.id)
  rescue => e
    diet&.update!(status: 'failed', generation_error: e.message)
    raise
  end
end
