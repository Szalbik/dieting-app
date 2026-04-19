# frozen_string_literal: true

class ProductCategoriesController < ApplicationController
  before_action :set_product_category, only: %i[edit show]
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
    product_name = params[:product_name].to_s.strip
    product_name = ProductCategory.find(params[:id]).product.name if product_name.blank?

    ProductCategory.assign_category_for_exact_name!(product_name, category_id: category_id)

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
    pending_rows = ProductCategory.pending_without_confirmed_counterpart
      .group_by { |pc| pc.product.name.to_s.downcase.strip }
      .values
      .map do |items|
        representative = items.first
        {
          id: representative.id,
          name: representative.product.name,
          category_id: representative.category_id,
          count: items.size,
        }
      end

    uncategorized_rows = Product.left_outer_joins(:product_category)
      .where(product_categories: { id: nil })
      .where(<<~SQL.squish)
        NOT EXISTS (
          SELECT 1
          FROM product_categories confirmed_pc
          INNER JOIN products confirmed_products ON confirmed_products.id = confirmed_pc.product_id
          WHERE confirmed_pc.state = TRUE
            AND LOWER(TRIM(confirmed_products.name)) = LOWER(TRIM(products.name))
        )
      SQL
      .group_by { |product| product.name.to_s.downcase.strip }
      .values
      .map do |items|
        representative = items.first
        {
          id: representative.id,
          name: representative.name,
          category_id: nil,
          count: items.size,
        }
      end

    (pending_rows + uncategorized_rows)
      .uniq { |row| row[:name].downcase.strip }
      .sort_by { |row| row[:name].downcase }
  end

  def require_admin!
    return if Current.user&.admin?

    redirect_to root_path, alert: 'Access denied.'
  end
end
