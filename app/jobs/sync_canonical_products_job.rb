# frozen_string_literal: true

class SyncCanonicalProductsJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    ActiveRecord::Base.transaction do
      refresh_existing_aliases!(user)

      user.product_substitutions.find_each do |substitution|
        substitution.send(:sync_canonical_products!)
        next unless substitution.changed?

        duplicate = user.product_substitutions
          .where(source_product: substitution.source_product, replacement_product: substitution.replacement_product)
          .where.not(id: substitution.id)
          .first

        if duplicate.present?
          duplicate.update!(
            source_amount: duplicate.source_amount.presence || substitution.source_amount,
            source_unit: duplicate.source_unit.presence || substitution.source_unit,
            replacement_amount: duplicate.replacement_amount.presence || substitution.replacement_amount,
            replacement_unit: duplicate.replacement_unit.presence || substitution.replacement_unit,
            amount_multiplier: duplicate.amount_multiplier.presence || substitution.amount_multiplier,
            source_canonical_product_id: duplicate.source_canonical_product_id.presence || substitution.source_canonical_product_id,
            replacement_canonical_product_id: duplicate.replacement_canonical_product_id.presence || substitution.replacement_canonical_product_id
          )
          substitution.destroy!
        else
          substitution.save!
        end
      end

      user.products.includes(meal: { diet_set: :diet }, diet_set: :diet).find_each do |product|
        product.sync_canonical_products!
        product.save! if product.changed?
      end
    end
  end

  private

  def refresh_existing_aliases!(user)
    normalizer = ShoppingList::ProductNormalizer.new

    user.canonical_products.includes(:canonical_product_aliases).find_each do |canonical|
      normalize_canonical_name!(canonical, normalizer)
      canonical.canonical_product_aliases.find_or_create_by!(name: canonical.name)

      canonical.canonical_product_aliases.order(:id).each do |alias_record|
        normalized_name = normalizer.cleaned_name(alias_record.name)
        duplicate = canonical.canonical_product_aliases
          .where(name: normalized_name)
          .where.not(id: alias_record.id)
          .first

        if duplicate.present?
          alias_record.destroy!
          next
        end

        alias_record.update!(name: normalized_name)
      end
    end
  end

  def normalize_canonical_name!(canonical, normalizer)
    normalized_name = normalizer.cleaned_name(canonical.name)
    return if normalized_name.blank? || normalized_name == canonical.name

    duplicate = canonical.user.canonical_products.where(name: normalized_name).where.not(id: canonical.id).first
    return if duplicate.present?

    canonical.update!(name: normalized_name)
  end
end
