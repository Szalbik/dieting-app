# frozen_string_literal: true

# Single source for how a category looks and where it sits on the shopping
# list: icon, card tint (Ui::CardComponent tints) and store-aisle position.
# Used by the cart view and by ShoppingCart#group_and_sum_by_cart_items.
# ponytail: keyed by Category#name; move to columns on categories if admins
# ever need to edit these.
module CategoriesHelper
  PRESENTATION = {
    'Warzywa' => { icon: '🥦', tint: :mint },
    'Owoce' => { icon: '🍎', tint: :peach },
    'Pieczywo' => { icon: '🍞', tint: :peach },
    'Nabiał' => { icon: '🥛', tint: :sky },
    'Mięso i Ryby' => { icon: '🍗', tint: :peach },
    'Wędliny' => { icon: '🥓', tint: :peach },
    'Produkty zbożowe' => { icon: '🌾', tint: :sky },
    'Tłuszcze i oleje' => { icon: '🫒', tint: :mint },
    'Przetwory' => { icon: '🥫', tint: :sky },
    'Przyprawy' => { icon: '🧂', tint: :sky },
    'Orzechy' => { icon: '🥜', tint: :peach },
    'Słodycze i przekąski' => { icon: '🍫', tint: :peach },
    'Produkty mrożone' => { icon: '🧊', tint: :sky },
    'Napoje' => { icon: '🧃', tint: :sky },
    'Inne' => { icon: '📦', tint: :sky },
  }.freeze
  DEFAULT_PRESENTATION = { icon: '🛒', tint: :sky }.freeze
  # Hash order above is the aisle order.
  POSITIONS = PRESENTATION.keys.each_with_index.to_h.freeze

  module_function

  def category_presentation(name)
    PRESENTATION.fetch(name, DEFAULT_PRESENTATION)
  end

  def category_position(name)
    POSITIONS.fetch(name, POSITIONS.size)
  end
end
