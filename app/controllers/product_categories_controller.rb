# frozen_string_literal: true

class ProductCategoriesController < ApplicationController
  PER_PAGE = 20

  before_action :set_product_category, only: %i[edit show]
  before_action :require_admin!

  def index
    @category_options = Category.order(:name).pluck(:name, :id)
    @pagy, classification_rows = pagy(:countless, classification_rows_scope, limit: PER_PAGE)
    @classification_rows = classification_rows.map do |row|
      {
        id: row.id,
        name: row.name,
        category_id: row.category_id,
        count: row.count.to_i,
      }
    end
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

    redirect_to product_categories_path(page: params[:page]), notice: 'Kategoria produktu została zaktualizowana.'
  end

  private

  def set_product_category
    @product_category = ProductCategory.find(params[:id])
  end

  def product_category_params
    params.require(:product_category).permit(:category_id, :state)
  end

  def classification_rows_scope
    confirmed_names_sql = ProductCategory
      .joins('INNER JOIN products ON products.id = product_categories.product_id')
      .where(state: true)
      .select('DISTINCT LOWER(TRIM(products.name)) AS normalized_name')
      .to_sql

    classified_names_sql = ProductCategory
      .joins('INNER JOIN products ON products.id = product_categories.product_id')
      .select('DISTINCT LOWER(TRIM(products.name)) AS normalized_name')
      .to_sql

    pending_sql = ProductCategory
      .joins('INNER JOIN products ON products.id = product_categories.product_id')
      .joins("LEFT JOIN (#{confirmed_names_sql}) confirmed_names ON confirmed_names.normalized_name = LOWER(TRIM(products.name))")
      .where(state: false)
      .where('confirmed_names.normalized_name IS NULL')
      .group('LOWER(TRIM(products.name))')
      .select(
        'MIN(product_categories.id) AS id',
        'MIN(products.name) AS name',
        'MIN(product_categories.category_id) AS category_id',
        'COUNT(*) AS count',
        'LOWER(TRIM(products.name)) AS normalized_name'
      )
      .to_sql

    uncategorized_sql = Product.left_outer_joins(:product_category)
      .joins("LEFT JOIN (#{classified_names_sql}) classified_names ON classified_names.normalized_name = LOWER(TRIM(products.name))")
      .where(product_categories: { id: nil })
      .where('classified_names.normalized_name IS NULL')
      .group('LOWER(TRIM(products.name))')
      .select(
        'MIN(products.id) AS id',
        'MIN(products.name) AS name',
        'NULL AS category_id',
        'COUNT(*) AS count',
        'LOWER(TRIM(products.name)) AS normalized_name'
      )
      .to_sql

    Product.unscoped
      .from("(#{pending_sql} UNION ALL #{uncategorized_sql}) classification_rows")
      .select('classification_rows.id, classification_rows.name, classification_rows.category_id, classification_rows.count')
      .order('classification_rows.normalized_name ASC')
  end

  def require_admin!
    return if Current.user&.admin?

    redirect_to root_path, alert: 'Access denied.'
  end
end
