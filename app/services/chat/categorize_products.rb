# frozen_string_literal: true

require 'openai'

module Chat
  class CategorizeProducts
    def self.call(products:, categories: Category.all, diet: nil)
      new(products: products, categories: categories, diet: diet).call
    end

    def initialize(products:, categories: Category.all, diet: nil)
      @products = @diet.nil? ? products : diet.products
      @categories = categories
      @client = OpenAI::Client.new(access_token: Rails.application.credentials.dig(:openai, :api_key))
    end

    def call
      response = client.chat(
        parameters: {
          model: model_engine, # Required.
          messages: [
            { role: 'system', content: system_prompt },
            { role: 'user', content: user_prompt },
          ], # Required.
          temperature: 0.7,
        })

      message = response.dig('choices', 0, 'message', 'content')
      assignments = message.split("\n")

      parsed_assignments = assignments.map do |assignment|
        assignment.split(' - ').map(&:strip)
      end

      parsed_assignments.each do |product_name, product_id, category_name, category_id|
        next if product_name.nil? || product_id.nil? || category_name.nil? || category_id.nil?

        product = products.find do |p|
          (p.id == product_id.split(' ').second.to_i && p.name == product_name) ||
          (p.id == product_id.split(' ').second.to_i) ||
          (p.name == product_name)
        end

        category = categories.find do |c|
          (c.id == category_id.split(' ').second.to_i && c.name == category_name) ||
          (c.id == category_id.split(' ').second.to_i) ||
          (c.name == category_name)
        end

        next if product.nil? || category.nil?

        ProductCategory.create!(product: product, category: category)
      end
    end

    private

    attr_reader :products, :categories, :client

    def system_prompt
      <<-HEREDOC
      As a sorting machine for groceries, your task is to assign each product to the correct category. Your role involves categorization only—no alterations to the product names. Your goal is to accurately sort each item into its respective category based on existing classifications.
      HEREDOC
    end

    def user_prompt
      <<-HEREDOC
      Available Categories:
      #{categories.map { |category| "#{category.name} - ID: #{category.id}" }.join("\n")}

      Available Products:
      #{products.map { |product| "#{product.name} - ID: #{product.id}" }.join("\n")}

      Assign each product to its appropriate category using the corresponding category name and ID. If a product seems ambiguous or could fit into multiple categories, choose the most fitting one based on common understanding.

      For example, [Product ID] and [Category ID] are numbers:
      "chleb razowy" - ID: [Product ID] - Pieczywo - ID: [Category ID]
      "sałata lodowa" - ID: [Product ID] - Warzywa - ID: [Category ID]

      Consider the nature of the product and its typical usage. The goal is to accurately categorize each item based on its usual classification. Keep in mind that products and categories are stored in the database. Return unchanged names, even if they contain a typo.

      For example, correcting an error in the product name, [Product ID] and [Category ID] are numbers:
      "orzechy ziemne" - ID: [Product ID] - Orzechy - ID: [Category ID]

      Output the list of products with their corresponding categories and their respective IDs.

      HEREDOC
    end

    def model_engine
      # 'text-davinci-003'
      'gpt-3.5-turbo'
    end
  end
end
