# frozen_string_literal: true

module Todoist
  class ResponseParser
    def initialize(api_response)
      @parsed_response = JSON.parse(api_response.body)
    end

    def get_param(param)
      @parsed_response[param]
    end

    def get_error_messages
      @parsed_response['Errors'].map { |error| error['Message'] }
    end
  end
end
