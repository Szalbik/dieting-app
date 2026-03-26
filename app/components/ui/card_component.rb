# frozen_string_literal: true

module Ui
  class CardComponent < ViewComponent::Base
    PADDING_CLASSES = {
      sm: 'p-4',
      md: 'p-6',
      lg: 'p-8'
    }.freeze

    def initialize(padding: :md, classes: nil)
      @padding = padding.to_sym
      @classes = classes
    end

    private

    attr_reader :padding, :classes

    def card_classes
      [
        'rounded-3xl border border-emerald-100/70 bg-white/90 shadow-soft backdrop-blur-sm',
        PADDING_CLASSES.fetch(padding, PADDING_CLASSES[:md]),
        classes
      ].compact.join(' ')
    end
  end
end
