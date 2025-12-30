# frozen_string_literal: true

class DietSet < ApplicationRecord
  belongs_to :diet
  has_many :meals, dependent: :destroy
  has_many :products, through: :meals
  has_many :diet_set_plans, dependent: :destroy

  validates :name, presence: true

  def derived_name_from_meal
    # Try to find obiad meal by meal_type first (more reliable)
    obiad_meal = meals.where(meal_type: ['lunch', 'dinner']).first
    # Fallback to name search if meal_type not available
    obiad_meal ||= meals.where('name LIKE ?', '%Obiad%').first

    return name unless obiad_meal

    meal_name = obiad_meal.name

    # If meal name doesn't contain "Obiad", it's likely from JSON parsing
    # and the name is already clean (e.g., "Fajita z kurczakiem")
    unless meal_name.downcase.include?('obiad')
      return meal_name.strip
    end

    # Try various patterns to extract the meal name after "Obiad"
    # Pattern 1: "2) Obiad: Kurczak z warzywami" or "Obiad: Kurczak z warzywami"
    if (match = meal_name.match(/Obiad[:\s]+(.+)/i))
      extracted = match[1].strip
      # Remove any leading numbers/parentheses that might have been included
      extracted = extracted.sub(/^\d+\)\s*/, '').strip
      return extracted unless extracted.empty?
    end

    # Pattern 2: "2) Obiad Kurczak z warzywami" (no colon)
    if (match = meal_name.match(/^\d+\)\s*Obiad\s+(.+)/i))
      return match[1].strip
    end

    # Pattern 3: "Obiad Kurczak z warzywami" (no colon, no number)
    if (match = meal_name.match(/^Obiad\s+(.+)/i))
      return match[1].strip
    end

    # Pattern 4: If meal name contains "Obiad" but doesn't match above patterns,
    # try to find where "Obiad" ends and extract from there
    if (obiad_index = meal_name.downcase.index('obiad'))
      # Find the end of "Obiad" word (after "d")
      after_obiad = meal_name[obiad_index + 5..-1]
      # Remove any colons, spaces, or numbers at the start
      cleaned = after_obiad.sub(/^[:\s\d\)]+/, '').strip
      return cleaned unless cleaned.empty?
    end

    # If all patterns fail, return the original name
    name
  end

  # Keep old method name for backward compatibility
  alias_method :derrivated_name_from_meal, :derived_name_from_meal
end
