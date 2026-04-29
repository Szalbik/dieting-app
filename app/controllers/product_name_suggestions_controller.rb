# frozen_string_literal: true

class ProductNameSuggestionsController < ApplicationController
  PER_PAGE = 20

  before_action :require_admin!

  def index
    @pagy, @suggestion_rows = pagy(:countless, suggestion_rows_scope, limit: PER_PAGE)
  end

  def update
    suggestion = ProductNameSuggestion.find(params[:id])

    case params[:action_type]
    when 'approve'
      approve_suggestion!(suggestion)
      redirect_to product_name_suggestions_path(page: params[:page]),
                  notice: 'Sugestia zatwierdzona i alias dodany.'
    when 'reject'
      suggestion.update!(status: 'rejected')
      redirect_to product_name_suggestions_path(page: params[:page]),
                  notice: 'Sugestia odrzucona.'
    else
      redirect_to product_name_suggestions_path, alert: 'Nieznana akcja.'
    end
  end

  private

  def approve_suggestion!(suggestion)
    ActiveRecord::Base.transaction do
      if suggestion.canonical_product.present?
        suggestion.canonical_product.canonical_product_aliases
          .find_or_create_by!(name: suggestion.raw_name)
      end

      suggestion.update!(status: 'approved')

      if suggestion.canonical_product.present?
        Product
          .where(canonical_product_id: nil)
          .where('LOWER(TRIM(name)) = LOWER(TRIM(?))', suggestion.raw_name)
          .update_all(
            canonical_product_id: suggestion.canonical_product_id,
            name: suggestion.canonical_product.name,
            updated_at: Time.current
          )
      end
    end
  end

  def suggestion_rows_scope
    ProductNameSuggestion
      .pending
      .joins('LEFT OUTER JOIN canonical_products ON canonical_products.id = product_name_suggestions.canonical_product_id')
      .joins('INNER JOIN users ON users.id = product_name_suggestions.user_id')
      .select(
        'product_name_suggestions.id',
        'product_name_suggestions.user_id',
        'product_name_suggestions.raw_name',
        'product_name_suggestions.canonical_product_id',
        'product_name_suggestions.confidence',
        'product_name_suggestions.match_type',
        'product_name_suggestions.occurrence_count',
        'canonical_products.name AS canonical_product_name',
        'users.email_address AS user_email'
      )
      .order('product_name_suggestions.occurrence_count DESC, product_name_suggestions.id ASC')
  end

  def require_admin!
    return if Current.user&.admin?

    redirect_to root_path, alert: 'Access denied.'
  end
end
