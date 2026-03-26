# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::DietParserService do
  subject(:service) { described_class.new('/tmp/example.pdf', expected_meals_per_day: 5) }

  let(:client) { instance_double(OpenAI::Client) }
  let(:response_json) do
    {
      days: [
        {
          day: 1,
          meals: [
            {
              type: 'breakfast',
              name: 'Kanapki',
              ingredients: [
                { product: 'pieczywo', quantity: '2 kromki' }
              ],
              instructions: '',
              nutrition: {
                kcal: 200,
                protein: 8,
                fat: 4,
                carbs: 30
              }
            }
          ]
        }
      ]
    }.to_json
  end

  before do
    allow(service).to receive(:openai_client).and_return(client)
    allow(DietJsonValidator).to receive(:validate!)
  end

  it 'sends page images to OpenAI when text comes from OCR' do
    captured_parameters = nil

    allow(service).to receive(:extract_pdf_content).and_return(
      PdfTextExtractor::Result.new(text: 'Roladkidrobiowe zcukiniq', page_count: 3, source: :ocr)
    )
    allow(service).to receive(:pdf_page_image_parts).and_return(
      [
        {
          type: 'image_url',
          image_url: { url: 'data:image/png;base64,abc', detail: 'high' }
        }
      ]
    )
    allow(client).to receive(:chat) do |parameters:|
      captured_parameters = parameters
      { 'choices' => [{ 'message' => { 'content' => response_json } }] }
    end

    service.call

    user_content = captured_parameters[:messages].last[:content]
    expect(user_content).to be_an(Array)
    expect(user_content.first).to include(type: 'text')
    expect(user_content.first[:text]).to include('OCR errors')
    expect(user_content.last).to include(type: 'image_url')
  end

  it 'keeps a text-only prompt when OCR was not used' do
    captured_parameters = nil

    allow(service).to receive(:extract_pdf_content).and_return(
      PdfTextExtractor::Result.new(text: 'ŚNIADANIE\nKanapki', page_count: 1, source: :pdftotext)
    )
    allow(client).to receive(:chat) do |parameters:|
      captured_parameters = parameters
      { 'choices' => [{ 'message' => { 'content' => response_json } }] }
    end

    service.call

    expect(captured_parameters[:messages].last[:content]).to be_a(String)
  end
end
