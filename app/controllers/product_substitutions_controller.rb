# frozen_string_literal: true

class ProductSubstitutionsController < ApplicationController
  MAX_PDF_BYTES = 10.megabytes

  rate_limit to: 5, within: 3.minutes, only: %i[import_pdf expand_ai rematch],
             with: -> { redirect_to product_substitutions_path, alert: 'Zbyt wiele prób. Spróbuj ponownie za kilka minut.' }

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
      source_product:      source,
      replacement_product: replacement,
      source_amount:       product_substitution_params[:source_amount].presence,
      source_unit:         ProductSubstitution.normalize_unit(product_substitution_params[:source_unit].to_s),
      replacement_amount:  product_substitution_params[:replacement_amount].presence,
      replacement_unit:    ProductSubstitution.normalize_unit(product_substitution_params[:replacement_unit].to_s)
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
    unless pdf_upload?(file)
      redirect_to product_substitutions_path, alert: 'Plik musi być PDF-em o rozmiarze do 10 MB.'
      return
    end
    unless params[:pii_confirmed] == '1' && (Current.user.consented?(:health_data) || params[:health_data] == '1')
      redirect_to product_substitutions_path,
                  alert: 'Potwierdź usunięcie danych osobowych z pliku i wyraź zgodę na przetwarzanie danych ' \
                         'dotyczących zdrowia.'
      return
    end
    # One paid OpenAI call per import: metered like a diet parse.
    unless Current.user.reserve_ai_quota!
      redirect_to product_substitutions_path, alert: ai_quota_exhausted_alert
      return
    end

    Current.user.record_consent!(:health_data) unless Current.user.consented?(:health_data)

    inserted = import_rows(Chat::ProductSubstitutionParserService.new(file.tempfile.path).call)

    SyncCanonicalProductsJob.perform_later(Current.user.id)
    MatchSubstitutionsToProductsJob.perform_later(Current.user.id)
    redirect_to product_substitutions_path, notice: "Zaimportowano #{inserted} zamienników. Trwa dopasowywanie do produktów z diety."
  rescue StandardError => e
    Current.user.refund_ai_quota! if Diet.refundable_error?(e)
    Honeybadger.notify(e) if defined?(Honeybadger)
    redirect_to product_substitutions_path, alert: 'Nie udało się zaimportować PDF. Sprawdź plik i spróbuj ponownie.'
  end

  def rematch
    SyncCanonicalProductsJob.perform_later(Current.user.id)
    MatchSubstitutionsToProductsJob.perform_later(Current.user.id)
    redirect_to product_substitutions_path, notice: 'Uruchomiono ponowne dopasowywanie AI zamienników do produktów.'
  end

  def expand_ai
    unless Current.user.reserve_ai_quota!
      redirect_to product_substitutions_path, alert: ai_quota_exhausted_alert
      return
    end

    ExpandSubstitutionsWithAiJob.perform_later(Current.user.id)
    redirect_to product_substitutions_path, notice: 'Uruchomiono rozszerzanie zamienników przez AI dla wszystkich produktów.'
  end

  private

  # Magic bytes, not the client-declared content type.
  def pdf_upload?(file)
    return false unless file.respond_to?(:tempfile) && file.size.to_i.between?(1, MAX_PDF_BYTES)

    Marcel::MimeType.for(file.tempfile, name: file.original_filename.to_s) == 'application/pdf'
  end

  def import_rows(rows)
    inserted = 0
    rows.each do |row|
      source = ProductSubstitution.canonical_name_for_user(user: Current.user, raw_name: row['source'].to_s)
      next if source.blank?

      Array(row['replacements']).each do |replacement|
        replacement_name = ProductSubstitution.canonical_name_for_user(user: Current.user, raw_name: replacement.to_s)
        next if replacement_name.blank?

        record = Current.user.product_substitutions.find_or_initialize_by(
          source_product: source, replacement_product: replacement_name
        )
        next unless record.new_record?

        record.save!
        inserted += 1
      end
    end
    inserted
  end

  def product_substitution_params
    params.require(:product_substitution).permit(
      :source_product, :replacement_product,
      :source_amount, :source_unit,
      :replacement_amount, :replacement_unit
    )
  end
end
