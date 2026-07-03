# frozen_string_literal: true

module DietsHelper
  DIET_GLYPHS = %w[🥗 🍗 🍑 🌊 🥑 🍓 🥘 🥦].freeze
  DIET_TILE_TINTS = %i[peach sky cream mint].freeze

  # Deterministic glyph/tint per diet so each card reads distinctly (mockup
  # TwojeDiety), without needing a stored field.
  def diet_glyph_for(diet)
    DIET_GLYPHS[diet.id % DIET_GLYPHS.size]
  end

  def diet_tile_tint_for(diet)
    DIET_TILE_TINTS[diet.id % DIET_TILE_TINTS.size]
  end

  # Sets-count cell: a status badge while an AI generation is running/failed,
  # otherwise the plain "N zestawów" count.
  def diet_sets_status(diet)
    case diet.status
    when 'generating'
      render(Ui::BadgeComponent.new(label: 'Generowanie…', variant: :accent))
    when 'failed'
      render(Ui::BadgeComponent.new(label: 'Błąd generowania', variant: :danger, classes: 'cursor-help', title: diet.generation_error))
    else
      "#{diet.diet_sets.count} zestawów"
    end
  end
end
