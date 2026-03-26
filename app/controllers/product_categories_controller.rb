# frozen_string_literal: true

class ProductCategoriesController < ApplicationController
  before_action :set_product_category, only: %i[edit update show]
  before_action :require_admin!

  def index
    @classification_rows = build_classification_rows
  end

  def show
    redirect_to product_categories_path
  end

  def edit
    redirect_to product_categories_path
  end

  def update
    category_id = product_category_params[:category_id]
    product_name = @product_category.product.name

    ProductCategory.confirm_pending_for_exact_name(product_name, category_id: category_id)

    redirect_to product_categories_path, notice: 'Kategoria produktu została zaktualizowana.'
  end

  private

  def set_product_category
    @product_category = ProductCategory.find(params[:id])
  end

  def product_category_params
    params.require(:product_category).permit(:category_id, :state)
  end

  def build_classification_rows
    ProductCategory.pending_without_confirmed_counterpart
      .group_by { |pc| pc.product.name.to_s.downcase.strip }
      .values
      .map do |items|
        representative = items.first
        {
          id: representative.id,
          name: representative.product.name,
          category_id: representative.category_id,
          count: items.size
        }
      end
      .sort_by { |row| row[:name].downcase }
  end

  def require_admin!
    return if Current.user&.admin?

    redirect_to root_path, alert: 'Access denied.'
  end
end
