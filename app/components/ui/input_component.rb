# frozen_string_literal: true

module Ui
  class InputComponent < ViewComponent::Base
    def initialize(label:, hint: nil, error: nil, classes: nil)
      @label = label
      @hint = hint
      @error = error
      @classes = classes
    end

    private

    attr_reader :label, :hint, :error, :classes
  end
end
