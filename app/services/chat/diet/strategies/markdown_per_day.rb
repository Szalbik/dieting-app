# frozen_string_literal: true

# Original pipeline: PDF -> per-page markdown (PyMuPDF4LLM, OCR fallback) ->
# regex day split -> one strict-JSON Chat Completions call per day. When the
# regex finds no day headings in a multi-page PDF, the model is asked for the
# heading line that opens each day (weekday-named plans, "Wariant A", ...).
class Chat::Diet::Strategies::MarkdownPerDay
  X = Chat::Diet::DayExtraction

  # Day headings sit at the top of each day, so the heading-detection call
  # never needs the whole document; cap it well under the model's context.
  HEADINGS_INPUT_LIMIT = 60_000

  HEADINGS_SCHEMA = {
    'type' => 'object',
    'required' => %w[days],
    'properties' => {
      'days' => {
        'type' => 'array',
        'items' => {
          'type' => 'object',
          'required' => %w[day heading],
          'properties' => { 'day' => { 'type' => 'integer' }, 'heading' => { 'type' => 'string' } },
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
    openai_client # build once; threads below share it
    day_schema = X.day_schema # one DB read, shared by the threads
    extraction = Chat::Diet::MarkdownExtractor.new(@file_path).extract
    @stats.source = extraction.source
    image_set = Chat::Diet::PageImageSet.new(@file_path)
    image_set.image_parts_for([]) if extraction.source == :ocr # render once, before threads

    X.in_parallel(day_chunks(extraction.pages), @concurrency) do |chunk|
      # Trust our own segmentation over the model's echoed "day" field.
      chat(day_prompt(chunk), day_schema, 'diet_parsing_day', images: ocr_images(extraction, image_set, chunk))
        .merge('day' => chunk.day)
    end
  ensure
    image_set&.cleanup
  end

  private

  def day_chunks(pages)
    segmenter = Chat::Diet::DaySegmenter.new(pages)
    chunks = segmenter.call
    return chunks unless segmenter.fallback? && Array(pages).size > 1

    headings = detect_headings(chunks.first.markdown)
    return chunks if headings.size <= 1

    Chat::Diet::DaySegmenter.new(pages, headings: headings).call
  end

  def detect_headings(markdown)
    prompt = <<~PROMPT
      This diet document contains several days but no "Dzień N"/"Zestaw N" headings.
      List the days in document order. For each, return "heading": the exact line of
      text (copied verbatim from the document) that starts that day, and "day": its
      1-based number (weekday names map to their order in the document).
      If the document describes a single day, return exactly one entry.

      Document:
      #{markdown.first(HEADINGS_INPUT_LIMIT)}
    PROMPT
    chat(prompt, HEADINGS_SCHEMA, 'diet_day_headings')['days'].to_h { |d| [d['heading'], d['day']] }
  end

  def day_prompt(chunk)
    <<~PROMPT
      #{X.rules(day: chunk.day, expected_meals_per_day: @expected_meals_per_day)}
      Day markdown (a table shows the meal columns for the day; the numbered
      headings below the table give per-meal ingredients/instructions):
      #{chunk.markdown}
    PROMPT
  end

  def ocr_images(extraction, image_set, chunk)
    extraction.source == :ocr ? image_set.image_parts_for(chunk.page_numbers) : []
  end

  def chat(prompt, schema, name, images: [])
    content = if images.empty?
      prompt
    else
      [{
        type: 'text', text: "#{prompt}\n\nIMPORTANT: The extracted text may contain OCR or page-break errors. " \
                             'Use the attached page images as the source of truth when the text and image disagree.'
      },
       *images]
    end

    response = X.with_api_errors do
      openai_client.chat(parameters: {
        model: @model,
        messages: [{ role: 'system', content: X::SYSTEM_PROMPT }, { role: 'user', content: content }],
        response_format: { type: 'json_schema', json_schema: { name: name, strict: true, schema: schema } },
        **X.chat_params(model: @model, reasoning_effort: @reasoning_effort),
      })
    end
    @stats_lock.synchronize { @stats.record(response['usage']) }
    X.parse_json(response.dig('choices', 0, 'message', 'content'))
  end

  def openai_client
    @_openai_client ||= X.client
  end
end
