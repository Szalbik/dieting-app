# frozen_string_literal: true

module Ui
  class SectionHeaderComponent < ViewComponent::Base
    def initialize(label:, title:, subtitle: nil, centered: false, classes: nil)
      @label = label
      @title = title
      @subtitle = subtitle
      @centered = centered
      @classes = classes
    end

    private

    attr_reader :label, :title, :subtitle, :centered, :classes

    def wrapper_classes
      [
        (centered ? 'text-center' : nil),
        classes
      ].compact.join(' ')
    end
  end
end
