# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('lib/diet_eval').to_s

# Live regression gate for the PDF parser (PRD FR-004). Calls the real OpenAI
# API with the default parser config over every corpus entry in
# spec/fixtures/diet_corpus/*/golden.json. Excluded from the default run:
#
#   bundle exec rspec --tag live_openai
#
# Run it before merging any change to the parser, its prompt or its schema.
RSpec.describe 'PDF parser regression', :live_openai do
  # Minimum per-PDF scores = corpus minimums of the shipped config
  # (native_pdf / none / gpt-5.1, 2026-09-28: composite 99.3, recall 0.98,
  # kcal 1.00) minus slack. See context/changes/pdf-parsing-quality/benchmark.md.
  thresholds = { composite: 96, ingredient_recall: 0.93, kcal_within_10pct: 0.95 }

  around do |example|
    WebMock.allow_net_connect!
    example.run
  ensure
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  entries = DietEval.entries
  it('has a corpus to check') { expect(entries).not_to be_empty }

  entries.each do |entry|
    it "parses #{entry.slug} at or above the thresholds" do
      run = DietEval.run(entry)

      expect(run.error).to be_nil
      thresholds.each do |metric, minimum|
        expect(run.score[metric]).to be >= minimum, "#{metric} #{run.score[metric]} < #{minimum}"
      end
    end
  end
end
