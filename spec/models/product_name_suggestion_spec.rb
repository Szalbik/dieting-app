# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProductNameSuggestion do
  describe "validations" do
    it { is_expected.to validate_presence_of(:raw_name) }
    it { is_expected.to validate_inclusion_of(:status).in_array(described_class::STATUSES) }
    it { is_expected.to validate_inclusion_of(:match_type).in_array(described_class::MATCH_TYPES) }
    it { is_expected.to validate_inclusion_of(:source).in_array(described_class::SOURCES) }
  end

  describe ".record_suggestion!" do
    let(:user)             { create(:user) }
    let(:canonical)        { create(:canonical_product, user: user) }
    let(:suggestion_attrs) do
      {
        user:              user,
        raw_name:          "tunczyk",
        canonical_product: canonical,
        confidence:        0.91,
        match_type:        "fuzzy",
        source:            "manual"
      }
    end

    it "creates a new pending suggestion when none exists" do
      expect { described_class.record_suggestion!(**suggestion_attrs) }
        .to change(described_class, :count).by(1)

      suggestion = described_class.last
      expect(suggestion.status).to eq("pending")
      expect(suggestion.occurrence_count).to eq(1)
      expect(suggestion.raw_name).to eq("tunczyk")
    end

    it "increments occurrence_count when a pending suggestion already exists for the same user and raw_name" do
      existing = described_class.record_suggestion!(**suggestion_attrs)

      expect { described_class.record_suggestion!(**suggestion_attrs) }
        .not_to change(described_class, :count)

      expect(existing.reload.occurrence_count).to eq(2)
    end

    it "creates a new suggestion (does not increment) when the existing one is rejected" do
      suggestion = described_class.record_suggestion!(**suggestion_attrs)
      suggestion.update!(status: "rejected")

      expect { described_class.record_suggestion!(**suggestion_attrs) }
        .to change(described_class, :count).by(1)
    end

    it "creates a new suggestion (does not increment) when the existing one is approved" do
      suggestion = described_class.record_suggestion!(**suggestion_attrs)
      suggestion.update!(status: "approved")

      expect { described_class.record_suggestion!(**suggestion_attrs) }
        .to change(described_class, :count).by(1)
    end
  end
end
