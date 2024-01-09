# frozen_string_literal: true

class FlashComponent < ViewComponent::Base
  def initialize(flash:)
    @flash = flash
  end

  def alert_color(key)
    case key
    when 'notice', 'success'
      'bg-green-50'
    when 'alert', 'error'
      'bg-red-50'
    when 'warning'
      'bg-yellow-50'
    else
      'bg-gray-50'
    end
  end

  def alert_icon_color(key)
    case key
    when 'notice', 'success'
      'text-green-400'
    when 'alert', 'error'
      'text-red-400'
    when 'warning'
      'text-yellow-400'
    else
      'text-gray-400'
    end
  end

  def alert_text_color(key)
    case key
    when 'notice', 'success'
      'text-green-800'
    when 'alert', 'error'
      'text-red-800'
    when 'warning'
      'text-yellow-800'
    else
      'text-gray-800'
    end
  end

  def alert_title(key)
    case key
    when 'notice', 'success'
      'Success'
    when 'alert', 'error'
      'Error'
    when 'warning'
      'Attention needed'
    else
      'Notice'
    end
  end
end
