# frozen_string_literal: true

class TrainCategoryModelJob < ApplicationJob
  queue_as :default

  def perform
    Classifier::Category.train!
  end
end
