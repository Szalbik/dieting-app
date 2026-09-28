# frozen_string_literal: true

# The model reads the PDF itself (Responses API `input_file`: extracted text +
# page images), so layout, tables and scans need no local extraction/OCR.
# Upload once, ask for a day outline, then one strict-JSON call per day against
# the same file_id (shared prefix -> cached-input pricing). The uploaded file
# is always deleted.
class Chat::Diet::Strategies::NativePdf
  X = Chat::Diet::DayExtraction

  OUTLINE_SCHEMA = {
    'type' => 'object',
    'required' => %w[days],
    'properties' => {
      'days' => {
        'type' => 'array',
        'items' => {
          'type' => 'object',
          'required' => %w[day title pages],
          'properties' => {
            'day' => { 'type' => 'integer' },
            'title' => { 'type' => 'string' },
            'pages' => { 'type' => 'array', 'items' => { 'type' => 'integer' } },
          },
          'additionalProperties' => false,
        },
      },
    },
    'additionalProperties' => false,
  }.freeze

  def initialize(file_path, stats:, expected_meals_per_day: nil, model: nil, reasoning_effort: nil, concurrency: 4)
    @file_path = file_path
    @stats = stats
    @expected_meals_per_day = expected_meals_per_day
    @model = model
    @reasoning_effort = reasoning_effort
    @concurrency = concurrency
    @stats_lock = Mutex.new
  end

  def call
    @stats.source = :native_pdf
    file_id = X.with_api_errors do
      client.files.upload(parameters: { file: @file_path.to_s, purpose: 'user_data' })['id']
    end

    outline = validate_outline(respond(outline_prompt, OUTLINE_SCHEMA, 'diet_outline', file_id)['days'])

    X.in_parallel(outline, @concurrency) do |entry|
      respond(day_prompt(entry), X::DAY_SCHEMA, 'diet_parsing_day', file_id).merge('day' => entry['day'])
    end
  ensure
    delete_upload(file_id) if file_id
  end

  private

  # Cheap sanity check before the paid per-day fan-out.
  def validate_outline(days)
    days = Array(days)
    raise 'Parser nie znalazł dni diety w PDF.' if days.empty?

    numbers = days.map { |d| d['day'].to_i }
    raise "Parser zwrócił nieprawidłowe numery dni: #{numbers.inspect}" if numbers.any? { |n| n < 1 }
    raise "Parser zwrócił zduplikowane numery dni: #{numbers.inspect}" if numbers.uniq.size != numbers.size

    days
  end

  # The user's PDF must not linger in OpenAI storage; a failed delete is an
  # incident, not a log line.
  def delete_upload(file_id)
    client.files.delete(id: file_id)
  rescue StandardError => e
    Rails.logger.error("NativePdf: could not delete uploaded file #{file_id}: #{e.message}")
    Honeybadger.notify(e, context: { file_id: file_id }) if defined?(Honeybadger)
  end

  def outline_prompt
    <<~PROMPT
      This PDF is a diet plan from a dietitian. List every diet day it contains, in order.
      For each day return: "day" (1-based number as labelled in the PDF, e.g. "Dzień 3"/"Zestaw 3" -> 3;
      weekday names -> their order in the document), "title" (the day's heading as printed) and
      "pages" (1-based page numbers holding that day's meals and recipes).
      A single-day plan returns exactly one entry. Do not list shopping lists, tips or cover pages as days.
    PROMPT
  end

  def day_prompt(entry)
    <<~PROMPT
      #{X.rules(day: entry['day'], expected_meals_per_day: @expected_meals_per_day)}
      Extract ONLY the day titled "#{entry['title']}" (PDF pages #{Array(entry['pages']).join(', ')}) from the attached PDF.
      Tables list the day's meals; recipe sections below give ingredients and instructions.
    PROMPT
  end

  def respond(prompt, schema, name, file_id)
    response = X.with_api_errors do
      client.responses.create(parameters: {
        model: @model,
        instructions: X::SYSTEM_PROMPT,
        input: [{
          role: 'user', content: [
          { type: 'input_file', file_id: file_id },
          { type: 'input_text', text: prompt },
        ]
        }],
        text: { format: { type: 'json_schema', name: name, strict: true, schema: schema } },
        **X.responses_params(model: @model, reasoning_effort: @reasoning_effort),
      })
    end
    @stats_lock.synchronize { @stats.record(response['usage']) }
    X.parse_json(output_text(response))
  end

  # Reasoning models emit a `reasoning` item before the `message` item.
  def output_text(response)
    if response['status'] == 'incomplete'
      raise "OpenAI response incomplete: #{response.dig('incomplete_details', 'reason')}"
    end

    message = Array(response['output']).find { |item| item['type'] == 'message' }
    raise "OpenAI returned no message (status #{response['status']})" unless message

    parts = Array(message['content'])
    refusal = parts.find { |part| part['type'] == 'refusal' }
    raise "OpenAI refused: #{refusal['refusal']}" if refusal

    parts.find { |part| part['type'] == 'output_text' }&.dig('text')
  end

  def client
    @_client ||= X.client
  end
end
