# frozen_string_literal: true

require 'openai'

class Chat::DietParserService
  def initialize(file_path, expected_meals_per_day: nil)
    @file_path = file_path
    @expected_meals_per_day = expected_meals_per_day
  end

  def call
    Chat::Diet::ParsingPipeline.new(
      @file_path,
      expected_meals_per_day: @expected_meals_per_day
    ).call
  end
end
