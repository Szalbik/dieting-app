# frozen_string_literal: true

module DietSetPlansHelper
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

  # Emoji glyph for a meal, keyed off its name (mirrors the UI kit's food tiles).
  def meal_glyph_for(meal)
    case meal.name.to_s.downcase
    when /śniadanie/ then '🥣'
    when /przekąska/, /drugie/ then '🍓'
    when /obiad/ then '🍝'
    when /kolacja/ then '🥗'
    else '🍽️'
    end
  end

  # :done / :current / :upcoming based on the meal's time window — only
  # meaningful for today; other days render neutral (:upcoming).
  def meal_status_for(meal, date)
    return :done if meal.try(:eaten?)

    time = meal_time_for(meal)
    return :upcoming unless date.to_s == Date.current.to_s && time.present?

    start_h = time[/\A\s*(\d{1,2})/, 1]&.to_i
    return :upcoming unless start_h

    end_h = time.scan(/(\d{1,2}):/).flatten.last.to_i
    now = Time.current.hour
    if now >= end_h then :done
    elsif now >= start_h then :current
    else :upcoming
    end
  end
end
