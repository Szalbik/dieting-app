# frozen_string_literal: true

module Ui
  class ButtonComponent < ViewComponent::Base
    VARIANT_CLASSES = {
      primary: 'bg-brand-navy text-white hover:bg-brand-navy-strong focus-visible:outline-brand-navy',
      secondary: 'border border-brand-ink/20 bg-white text-brand-ink ' \
                 'hover:border-brand-navy hover:text-brand-navy focus-visible:outline-brand-navy',
      peach: 'bg-brand-peach text-brand-ink hover:bg-brand-peach-strong focus-visible:outline-brand-peach-strong',
      ghost: 'bg-transparent text-brand-ink-soft hover:bg-brand-paper focus-visible:outline-brand-navy',
      danger: 'bg-rose-600 text-white hover:bg-rose-500 focus-visible:outline-rose-600',
    }.freeze

    SIZE_CLASSES = {
      sm: 'px-3 py-2 text-sm',
      md: 'px-4 py-2.5 text-sm',
      lg: 'px-6 py-3 text-base',
    }.freeze

    def initialize(href: nil, variant: :primary, size: :md, full_width: false, type: 'button', classes: nil)
      @href = href
      @variant = variant.to_sym
      @size = size.to_sym
      @full_width = full_width
      @type = type
      @classes = classes
    end

    private

    attr_reader :href, :variant, :size, :full_width, :type, :classes

    def button_classes
      [
        'inline-flex min-h-11 items-center justify-center rounded-full border border-transparent font-semibold transition-all duration-200',
        'focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2',
        (full_width ? 'w-full' : nil),
        VARIANT_CLASSES.fetch(variant, VARIANT_CLASSES[:primary]),
        SIZE_CLASSES.fetch(size, SIZE_CLASSES[:md]),
        classes,
      ].compact.join(' ')
    end
  end
end
