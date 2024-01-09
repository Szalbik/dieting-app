# frozen_string_literal: true

require 'nbayes'

module Classifier
  class Category
    PATH = Rails.root.join('app/services/classifier/category_model.dat').to_path

    def self.predict(product_name)
      new.predict(product_name)
    end

    def self.train!
      new(skip_load: true)
    end

    def initialize(skip_load: false)
      if skip_load
        initialize_nbayes
      else
        load_model || initialize_nbayes
      end
    end

    def predict(product_name)
      products = ProductCategory.joins(:product, :category).where(state: true).where('products.name = ?', "#{product_name}")
      if products.present?
        category_name = products.first.category.name
        { name: category_name, state: true }
      else
        category_name = @nbayes.classify(product_name.split(/\s+/)).max_class
        { name: category_name, state: false }
      end
    end

    private

    def load_model
      if File.exist?(PATH)
        serialized_data = File.read(PATH)
        @nbayes = Marshal.load(serialized_data)
      else
        false
      end
    end

    def initialize_nbayes
      @nbayes = NBayes::Base.new

      ProductCategory.where(state: true).includes(:product, :category).find_each do |pc|
        100.times do
          @nbayes.train(pc.product.name.split(/\s+/), pc.category.name)
        end
      end

      serialized_data = Marshal.dump(@nbayes)
      File.open(PATH, 'wb') { |f| f.write(serialized_data) }
    end
  end
end
