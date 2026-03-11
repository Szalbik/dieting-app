# frozen_string_literal: true

class ProductSubstitutionsController < ApplicationController
  def index
    @product_substitutions = Current.user.product_substitutions.order(:source_product, :replacement_product)
  end

  def create
    source = ProductSubstitution.canonical_name_for_user(
      user: Current.user,
      raw_name: product_substitution_params[:source_product]
    )
    replacement = ProductSubstitution.canonical_name_for_user(
      user: Current.user,
      raw_name: product_substitution_params[:replacement_product]
    )
    substitution = Current.user.product_substitutions.new(
      source_product: source,
      replacement_product: replacement
    )

    if substitution.save
      SyncCanonicalProductsJob.perform_later(Current.user.id)
      MatchSubstitutionsToProductsJob.perform_later(Current.user.id)
      redirect_to product_substitutions_path, notice: 'Zamiennik został dodany.'
    else
      redirect_to product_substitutions_path, alert: substitution.errors.full_messages.to_sentence
    end
  end

  def destroy
    substitution = Current.user.product_substitutions.find(params[:id])
    substitution.destroy
    SyncCanonicalProductsJob.perform_later(Current.user.id)
    MatchSubstitutionsToProductsJob.perform_later(Current.user.id)
    redirect_to product_substitutions_path, notice: 'Zamiennik został usunięty.'
  end

  def import_pdf
    file = params[:pdf]
    if file.blank?
      redirect_to product_substitutions_path, alert: 'Wybierz plik PDF z listą zamienników.'
      return
    end

    rows = Chat::ProductSubstitutionParserService.new(file.tempfile.path).call
    inserted = 0

    rows.each do |row|
      source = ProductSubstitution.canonical_name_for_user(
        user: Current.user,
        raw_name: row['source'].to_s
      )
      next if source.blank?

      Array(row['replacements']).each do |replacement|
        replacement_name = ProductSubstitution.canonical_name_for_user(
          user: Current.user,
          raw_name: replacement.to_s
        )
        next if replacement_name.blank?

        record = Current.user.product_substitutions.find_or_initialize_by(
          source_product: source,
          replacement_product: replacement_name
        )
        next unless record.new_record?

        record.save!
        inserted += 1
      end
    end

    SyncCanonicalProductsJob.perform_later(Current.user.id)
    MatchSubstitutionsToProductsJob.perform_later(Current.user.id)
    redirect_to product_substitutions_path, notice: "Zaimportowano #{inserted} zamienników. Trwa dopasowywanie do produktów z diety."
  rescue StandardError => e
    redirect_to product_substitutions_path, alert: "Nie udało się zaimportować PDF: #{e.message}"
  end

  def rematch
    SyncCanonicalProductsJob.perform_later(Current.user.id)
    MatchSubstitutionsToProductsJob.perform_later(Current.user.id)
    redirect_to product_substitutions_path, notice: 'Uruchomiono ponowne dopasowywanie AI zamienników do produktów.'
  end

  def expand_ai
    ExpandSubstitutionsWithAiJob.perform_later(Current.user.id)
    redirect_to product_substitutions_path, notice: 'Uruchomiono rozszerzanie zamienników przez AI dla wszystkich produktów.'
  end

  private

  def product_substitution_params
    params.require(:product_substitution).permit(:source_product, :replacement_product)
  end
end
