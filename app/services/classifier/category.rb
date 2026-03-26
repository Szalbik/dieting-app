# frozen_string_literal: true

require 'fileutils'
require 'nbayes'

module Classifier
  class Category
    PATH = Rails.root.join('tmp/classifier/category_model.dat').to_path
    MIN_CONFIDENCE = 0.45
    SIMILARITY_THRESHOLD = 0.6
    IGNORED_TOKENS = %w[g kg dag mg ml l szt sztuk op opak opakowanie opakowania].freeze

    def self.predict(product_name)
      new.predict(product_name)
    end

    def self.train!
      new(skip_load: true)
    end

    def self.normalize_name(product_name)
      product_name.to_s.downcase
                  .gsub(/[^[:alnum:]\s]/, ' ')
                  .gsub(/\b\d+(?:[.,]\d+)?\b/, ' ')
                  .gsub(/\s+/, ' ')
                  .strip
    end

    def self.tokens_for(product_name)
      normalize_name(product_name).split.filter_map do |token|
        next if token.length < 2 || IGNORED_TOKENS.include?(token)

        token
      end
    end

    def initialize(skip_load: false)
      if skip_load
        initialize_nbayes
      else
        load_model || initialize_nbayes
      end
    end

    def predict(product_name)
      normalized_name = self.class.normalize_name(product_name)
      return blank_prediction if normalized_name.blank?

      exact_match = confirmed_examples.find { |pc| normalized_product_name(pc) == normalized_name }
      return build_prediction(name: exact_match.category.name, state: true, confidence: 1.0) if exact_match

      similar_match = best_confirmed_match(normalized_name)
      if similar_match
        return build_prediction(
          name: similar_match.fetch(:product_category).category.name,
          state: false,
          confidence: similar_match.fetch(:score)
        )
      end

      tokens = self.class.tokens_for(product_name)
      return blank_prediction if tokens.empty? || confirmed_examples.empty?

      classification = @nbayes.classify(tokens)
      category_name = classification.max_class
      confidence = category_name.present? ? classification[category_name].to_f : 0.0
      return blank_prediction if category_name.blank? || confidence < MIN_CONFIDENCE

      build_prediction(name: category_name, state: false, confidence: confidence)
    rescue StandardError => e
      Rails.logger.error("Category classifier failed for '#{product_name}': #{e.message}")
      blank_prediction
    end

    private

    def load_model
      return false unless File.exist?(PATH)

      serialized_data = File.binread(PATH)
      @nbayes = Marshal.load(serialized_data)
      true
    rescue StandardError => e
      Rails.logger.warn("Falling back to retraining category model: #{e.message}")
      false
    end

    def initialize_nbayes
      @nbayes = NBayes::Base.new

      confirmed_examples.each do |pc|
        tokens = self.class.tokens_for(pc.product.name)
        next if tokens.empty?

        @nbayes.train(tokens, pc.category.name)
      end

      persist_model!
    end

    def confirmed_examples
      @confirmed_examples ||= ProductCategory.where(state: true).includes(:product, :category).to_a
    end

    def normalized_product_name(product_category)
      self.class.normalize_name(product_category.product.name)
    end

    def best_confirmed_match(normalized_name)
      target_tokens = self.class.tokens_for(normalized_name)
      return if target_tokens.empty?

      confirmed_examples.filter_map do |product_category|
        candidate_name = normalized_product_name(product_category)
        score = similarity_score(
          target_name: normalized_name,
          target_tokens: target_tokens,
          candidate_name: candidate_name
        )
        next if score < SIMILARITY_THRESHOLD

        { product_category: product_category, score: score }
      end.max_by { |candidate| candidate.fetch(:score) }
    end

    def similarity_score(target_name:, target_tokens:, candidate_name:)
      candidate_tokens = self.class.tokens_for(candidate_name)
      return 0.0 if candidate_tokens.empty?

      intersection_size = (target_tokens & candidate_tokens).size
      union_size = (target_tokens | candidate_tokens).size
      token_score = union_size.zero? ? 0.0 : intersection_size.to_f / union_size
      substring_bonus = target_name.include?(candidate_name) || candidate_name.include?(target_name) ? 0.35 : 0.0
      prefix_bonus = target_tokens.first == candidate_tokens.first ? 0.15 : 0.0

      token_score + substring_bonus + prefix_bonus
    end

    def persist_model!
      FileUtils.mkdir_p(File.dirname(PATH))
      File.binwrite(PATH, Marshal.dump(@nbayes))
    end

    def blank_prediction
      build_prediction(name: nil, state: false, confidence: 0.0)
    end

    def build_prediction(name:, state:, confidence:)
      { name: name, state: state, confidence: confidence }
    end
  end
end
