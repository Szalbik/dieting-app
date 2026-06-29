# frozen_string_literal: true

module Ui
  class BadgeComponent < ViewComponent::Base
    VARIANT_CLASSES = {
      neutral: 'bg-white text-brand-ink-soft ring-brand-ink/10',
      success: 'bg-brand-mint-soft text-brand-mint-strong ring-brand-mint/60',
      accent: 'bg-brand-peach-soft text-brand-peach-strong ring-brand-peach/60',
      info: 'bg-brand-sky-soft text-brand-sky-strong ring-brand-sky/60',
    }.freeze

    def initialize(label:, variant: :neutral, classes: nil)
      @label = label
      @variant = variant.to_sym
      @classes = classes
    end

    private

    attr_reader :label, :variant, :classes

    def badge_classes
      [
        'inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ring-1 ring-inset',
        VARIANT_CLASSES.fetch(variant, VARIANT_CLASSES[:neutral]),
        classes,
      ].compact.join(' ')
    end
  end
end
