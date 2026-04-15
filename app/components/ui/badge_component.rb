# frozen_string_literal: true

module Ui
  class BadgeComponent < ViewComponent::Base
    VARIANT_CLASSES = {
      neutral: 'bg-slate-100 text-slate-700 ring-slate-300/80',
      success: 'bg-emerald-100 text-emerald-700 ring-emerald-300/80',
      accent: 'bg-orange-100 text-orange-700 ring-orange-300/80',
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
