# frozen_string_literal: true

module Ui
  class CardComponent < ViewComponent::Base
    PADDING_CLASSES = {
      sm: 'p-4',
      md: 'p-6',
      lg: 'p-8',
    }.freeze

    # Tinted surfaces from the Peach Skyline kit (exact color-mix recipes
    # live in application.tailwind.css as .dietcard-* classes). nil = white.
    TINT_CLASSES = {
      peach: 'dietcard-peach',
      sky:   'dietcard-sky',
      mint:  'dietcard-mint',
      navy:  'dietcard-navy',
    }.freeze

    def initialize(padding: :md, tint: nil, classes: nil)
      @padding = padding.to_sym
      @tint = tint&.to_sym
      @classes = classes
    end

    private

    attr_reader :padding, :tint, :classes

    def card_classes
      [
        'shadow-soft',
        tint ? TINT_CLASSES.fetch(tint) : 'dietcard',
        PADDING_CLASSES.fetch(padding, PADDING_CLASSES[:md]),
        classes,
      ].compact.join(' ')
    end
  end
end
