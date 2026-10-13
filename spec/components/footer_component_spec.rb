# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FooterComponent, type: :component do
  include ViewComponent::TestHelpers

  it 'names the brand and the sole proprietorship, not an Inc.' do
    render_inline(described_class.new)

    expect(rendered_content).to include('AsystentDiety')
    expect(rendered_content).to include('Wszelkie prawa zastrzeżone')
    expect(rendered_content).not_to include('All rights reserved')
  end
end
