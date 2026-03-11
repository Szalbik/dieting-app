# frozen_string_literal: true

class MatchSubstitutionsToProductsJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    SyncCanonicalProductsJob.perform_now(user.id) if user.canonical_products.empty?

    source_products = user.product_substitutions.pluck(:source_product).uniq
    diet_product_names = user.products.pluck(:name).uniq
    return if source_products.empty? || diet_product_names.empty?

    mappings = Local::SubstitutionProductMatcherService.new(
      source_products: source_products,
      diet_product_names: diet_product_names
    ).call

    ActiveRecord::Base.transaction do
      user.substitution_product_matches.delete_all

      mappings.each do |mapping|
        source = mapping['source_product'].to_s.strip
        next if source.blank?

        Array(mapping['matches']).each do |matched|
          matched_name = matched['name'].to_s.strip
          confidence = matched['score'].to_f
          next if matched_name.blank?

          user.substitution_product_matches.create!(
            source_product: source,
            matched_product_name: matched_name,
            confidence: confidence
          )
        end
      end
    end
  end
end
