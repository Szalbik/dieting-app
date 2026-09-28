# frozen_string_literal: true

# Data migration: two real categories so oils and snacks stop landing in "Inne",
# and removal of test-artifact categories ("Warzywa-d5ea0648").
class AddFatsAndSnacksCategories < ActiveRecord::Migration[8.0]
  FATS = 'Tłuszcze i oleje'
  SNACKS = 'Słodycze i przekąski'
  REPOINT = { FATS => %w[oliw olej], SNACKS => %w[baton czekolad ciast wafel] }.freeze
  JUNK_SUFFIX_GLOB = "*-#{'[0-9a-f]' * 8}".freeze

  def up
    Category.where('name GLOB ?', JUNK_SUFFIX_GLOB).find_each(&:destroy)

    inne = Category.find_by(name: 'Inne')
    REPOINT.each do |target_name, stems|
      target = Category.find_or_create_by!(name: target_name)
      stems.each { |stem| repoint_confirmed!(from: inne, to: target, stem: stem) } if inne
    end

    TrainCategoryModelJob.perform_later
  end

  # Assignments go back to "Inne" rather than vanishing with the categories.
  # Junk categories removed in #up are not restored.
  def down
    added = Category.where(name: [FATS, SNACKS])
    inne = Category.find_or_create_by!(name: 'Inne')
    ProductCategory.where(category_id: added.select(:id))
                   .update_all(category_id: inne.id, updated_at: Time.current)
    added.find_each(&:destroy)
  end

  private

  # update_all skips ProductCategory callbacks on purpose; retrain is enqueued once in #up.
  def repoint_confirmed!(from:, to:, stem:)
    ProductCategory.joins(:product)
                   .where(category_id: from.id, state: true)
                   .where('LOWER(products.name) LIKE ?', "%#{stem}%")
                   .update_all(category_id: to.id, updated_at: Time.current)
  end
end
