# frozen_string_literal: true

require 'json'
require 'openai'

# Last-resort AI fallback for product categorization. Called only for products
# the local Classifier::Category (exact/similarity/keyword/NBayes) couldn't
# place — batched, never per-product, to keep this cheap. Reuses the same
# structured-output pattern as Chat::MealMacroEstimatorService.
class Chat::ProductCategorizerService
  def initialize(products:)
    @products = Array(products)
  end

  def call
    return if products.empty? || category_names.empty? || !api_key?

    assignments.each do |assignment|
      product = products_by_id[assignment['product_id']]
      category = categories_by_name[assignment['category']]
      next if product.blank? || category.blank? || product.category.present?

      ProductCategory.create!(product: product, category: category, state: false)
    end
  rescue StandardError => e
    Rails.logger.error("Chat::ProductCategorizerService failed: #{e.message}")
  end

  private

  attr_reader :products

  def assignments
    response = openai_client.chat(
      parameters: {
        model: model,
        messages: [
          { role: 'system', content: 'You are a grocery-sorting assistant. Assign each product to the single best-fitting category.' },
          { role: 'user', content: prompt },
        ],
        temperature: 0.2,
        response_format: {
          type: 'json_schema',
          json_schema: { name: 'product_categorization', strict: true, schema: schema },
        },
      }
    )

    json_str = response.dig('choices', 0, 'message', 'content')
    JSON.parse(json_str.to_s.gsub(/\A```json\s*\n?/, '').gsub(/```$/, '').strip)['assignments']
  end

  def prompt
    <<~PROMPT
      Available categories: #{category_names.join(', ')}

      Products to categorize:
      #{products.map { |p| "#{p.id} - #{p.name}" }.join("\n")}

      Assign every product to exactly one of the available categories.
    PROMPT
  end

  def schema
    {
      'type' => 'object',
      'required' => ['assignments'],
      'properties' => {
        'assignments' => {
          'type' => 'array',
          'items' => {
            'type' => 'object',
            'required' => %w[product_id category],
            'properties' => {
              'product_id' => { 'type' => 'integer' },
              'category' => { 'type' => 'string', 'enum' => category_names },
            },
            'additionalProperties' => false,
          },
        },
      },
      'additionalProperties' => false,
    }
  end

  def products_by_id
    @products_by_id ||= products.index_by(&:id)
  end

  def categories_by_name
    @categories_by_name ||= Category.where(name: category_names).index_by(&:name)
  end

  def category_names
    @category_names ||= Category.pluck(:name)
  end

  def api_key?
    Rails.application.credentials.dig(:openai, :api_key).present?
  end

  def openai_client
    @_openai_client ||= OpenAI::Client.new(
      request_timeout: 120,
      access_token: Rails.application.credentials.dig(:openai, :api_key)
    )
  end

  def model
    Rails.application.config.x.openai.diet_parsing_model
  end
end
