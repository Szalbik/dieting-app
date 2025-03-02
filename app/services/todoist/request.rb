# frozen_string_literal: true

module Todoist
  class Request
    API_URL = 'https://api.todoist.com/rest/v2'

    class << self
      def create_task(tasks, categories, token, project_id)
        tasks.map do |item|
          {
            project_id: project_id,
            section_id: categories.find { |c| c[:name] == item.last[:category] }&.dig(:id),
            content: item.first,
            description: item.second[:measurements].map { |m| "#{m[:amount].to_i}#{m[:unit]}" }.join(', '),
          }
        end.each do |task|
          res = HTTParty.post(API_URL + '/tasks',
                        headers: headers.merge({ 'Authorization' => "Bearer #{token['token']}" }),
                        body: task.to_json)
        end

        true
      end

      def fetch_sections(token, project_id)
        HTTParty.get(API_URL + '/sections?project_id=' + project_id,
                     headers: headers.merge({ 'Authorization' => "Bearer #{token['token']}" }))
      end

      def create_section(category, token, project_id)
        body = {
          name: category.name,
          project_id: project_id,
        }

        HTTParty.post(API_URL + '/sections',
                      headers: headers.merge({ 'Authorization' => "Bearer #{token['token']}" }),
                      body: body.to_json)
      end

      def fetch_projects(token)
        HTTParty.get(API_URL + '/projects',
                     headers: headers.merge({ 'Authorization' => "Bearer #{token['token']}" }))
      end

      private

      def auth_code_url
        "https://todoist.com/oauth/authorize?client_id=#{client_id}&scope=#{client_scope}&state=#{state}"
      end

      def client_id
        Rails.application.credentials.todoist[:client_id]
      end

      def client_scope
        Rails.application.credentials.todoist[:client_scope]
      end

      def state
        Rails.application.credentials.todoist[:state]
      end

      def headers
        { 'Content-Type' => 'application/json' }
      end

      def make_request
        response = yield
        return response if response.status == 200

        false
      end

      def api_errors(response)
        # Refactor it
        begin
          return Todoist::ResponseParser.new(response).get_error_messages if response.status.to_s.match?(/4\d{2}/)
        rescue StandardError
          return ['Unknown external API error']
        end

        ['Unknown external API error']
      end
    end
  end
end
