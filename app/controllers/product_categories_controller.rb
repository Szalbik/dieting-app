# frozen_string_literal: true

class ProductCategoriesController < ApplicationController
  before_action :set_product_category, only: %i[edit update show]

  def index
    @product_categories = ProductCategory.where(state: false)
  end

  def show
    respond_to do |format|
      format.html {}
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "product_category_#{@product_category.id}",
          partial: 'product_categories/product_category',
          locals: { pc: @product_category }
        )
      end
    end
  end

  def edit
    render turbo_stream: turbo_stream.replace(
      "product_category_#{@product_category.id}",
      partial: 'product_categories/form_row',
      locals: { pc: @product_category }
    )
  end

  def update
    if @product_category.update(product_category_params)
      product = @product_category.product
      ProductCategory.confirm_state_for(product.name, @product_category.category.name)
      render turbo_stream: turbo_stream.remove(
        "product_category_#{@product_category.id}"
        # partial: 'product_categories/product_category',
        # locals: { pc: @product_category }
      )
    else
      render turbo_stream: turbo_stream.replace(
        "product_category_#{@product_category.id}",
        partial: 'product_categories/form_row',
        locals: { pc: @product_category }
      )
    end
  end

  private

  def set_product_category
    @product_category = ProductCategory.find(params[:id])
  end

  def product_category_params
    params.require(:product_category).permit(:category_id, :state)
  end
end
