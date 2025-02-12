# frozen_string_literal: true

module MealPlansHelper
  def meal_time_for(meal)
    case meal.name.downcase
    when /śniadanie/
      '8:00 - 9:00'
    when /przekąska/
      '11:00 - 12:00'
    when /obiad/
      '14:00 - 15:00'
    when /kolacja/
      '18:00 - 19:00'
    when /dodatkowy/
      '12:22'
    else
      ''
    end
  end
end
