# frozen_string_literal: true

class ExpandSubstitutionsWithAiJob < ApplicationJob
  queue_as :default

  MIN_CONFIDENCE = 0.65
  CATEGORY_RULES = {
    /owoc/i => %w[banan jablk gruszk kiwi mango arbuz borow malin truskawk ananas pomarancz mandaryn winogron nektaryn brzoskwin
czere],
    /pieczywo/i => %w[chleb bulk kajzer graham bagiet pita tortilla],
    /napoj/i => %w[herbat kaw wod sok napoj kefir maslank mleko],
  }.freeze

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    catalog = build_catalog(user)
    existing = existing_substitutions_map(user)
    return if catalog.empty?

    mappings = Chat::SubstitutionExpanderService.new(
      product_catalog: catalog,
      existing_substitutions: existing
    ).call

    create_suggestions(user, mappings, existing)
    create_category_based_suggestions(user)
    SyncCanonicalProductsJob.perform_later(user.id)
    MatchSubstitutionsToProductsJob.perform_later(user.id)
  end

  private

  def build_catalog(user)
    user.products.includes(:category).map do |product|
      {
        name: ProductSubstitution.strip_quantity_from_name(product.name),
        category: product.category_name_or_default,
      }
    end.uniq { |row| row[:name].downcase }
  end

  def existing_substitutions_map(user)
    user.product_substitutions.group_by(&:source_product).transform_values do |subs|
      subs.map(&:replacement_product).uniq
    end
  end

  def create_suggestions(user, mappings, existing)
    mappings.each do |row|
      source = ProductSubstitution.canonical_name_for_user(user: user, raw_name: row['source_product'].to_s)
      next if source.blank?
      next unless existing.key?(source)

      Array(row['replacements']).each do |replacement_row|
        replacement = ProductSubstitution.canonical_name_for_user(user: user, raw_name: replacement_row['name'].to_s)
        confidence = replacement_row['confidence'].to_f
        next if replacement.blank? || replacement.casecmp(source).zero?
        next if confidence < MIN_CONFIDENCE
        next if existing[source]&.include?(replacement)

        user.product_substitutions.find_or_create_by!(
          source_product: source,
          replacement_product: replacement
        )
      end
    end
  end

  def create_category_based_suggestions(user)
    groups = user.products
      .includes(:category)
      .group_by { |product| product.category_name_or_default }
      .transform_values do |products|
        products.map { |p| ProductSubstitution.strip_quantity_from_name(p.name) }.uniq
      end

    groups.each do |category_name, names|
      rule, keywords = CATEGORY_RULES.find { |regex, _keywords| category_name.to_s.match?(regex) }
      next unless rule

      filtered_names = names.select do |name|
        normalized = ProductSubstitution.normalize_name(name)
        keywords.any? { |keyword| normalized.include?(keyword) }
      end
      names = filtered_names.uniq
      next if names.size < 2

      names.each do |source|
        names.each do |replacement|
          next if source == replacement

          user.product_substitutions.find_or_create_by!(
            source_product: ProductSubstitution.canonical_name_for_user(user: user, raw_name: source),
            replacement_product: ProductSubstitution.canonical_name_for_user(user: user, raw_name: replacement)
          )
        end
      end
    end
  end
end
