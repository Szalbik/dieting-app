# frozen_string_literal: true

require 'openai'

module Chat
  class Gpt
    def initialize
      OpenAI.api_key = Rails.application.credentials.openai[:api_key]
    end

    def generate_response(message)
      completions = OpenAI.Completion.create(
        engine: model_engine,
        prompt: prompt,
        max_tokens: 60,
        n: 1,
        stop: "\n",
        temperature: 0.5
      )
      message = completions.choices[0].text.strip
      message
    end
  end
end
