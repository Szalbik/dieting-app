# frozen_string_literal: true

module Todoist
  class Api
    # def self.token
    #   response = Request.token
    #   ResponseParser.new(response).get_param('token')
    # end

    def self.create_task(products, categories, token, project_id)
      response = Request.create_task(products, categories, token, project_id)

      if response
        { success: true }
      else
        { success: false }
      end
    end

    def self.create_section(category, token, project_id)
      response = Request.create_section(category, token, project_id)

      {
        success: true,
        id: ResponseParser.new(response).get_param('id'),
        name: ResponseParser.new(response).get_param('name'),
        category_id: category.id,
        project_id: ResponseParser.new(response).get_param('project_id'),
      }
    end

    def self.fetch_projects(token)
      Request.fetch_projects(token)
    end

    def self.fetch_sections(token, project_id)
      Request.fetch_sections(token, project_id)
    end
  end
end
