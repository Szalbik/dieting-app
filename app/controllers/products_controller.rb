# frozen_string_literal: true

class ProductsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_product, only: %i[show edit update destroy]

  # GET /products or /products.json
  def index
    @diet_set_ids = search_params[:diet][:diet_set_ids].reject(&:empty?) rescue []
    @diet_set_quantities = search_params[:diet][:diet_set_quantities] rescue {}

    # Step 1: Filter products based on selected diet sets
    products = current_user.active_products.where(diet_set_id: @diet_set_ids)

    # Step 2: Prepare products with quantities
    multiplied_products = []
    if @diet_set_quantities.present?
      @diet_set_quantities.each do |diet_set_id, quantity|
        next unless @diet_set_ids.include?(diet_set_id)
        quantity = quantity.to_i
        # Assuming each product should be duplicated based on the quantity
        products.where(diet_set_id: diet_set_id).each do |product|
          quantity.times { multiplied_products << product}
        end
      end
    else
      multiplied_products = products
    end

    @products = Product.group_and_sum_by_name_then_category(multiplied_products)
  end

  # GET /products/1 or /products/1.json
  def show; end

  # GET /products/new
  def new
    @product = Product.new
  end

  # GET /products/1/edit
  def edit; end

  # POST /products or /products.json
  def create
    @product = Product.new(product_params)

    respond_to do |format|
      if @product.save
        format.html { redirect_to new_product_path, notice: 'Product was successfully created.' }
        format.json { render :show, status: :created, location: @product }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @product.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /products/1 or /products/1.json
  def update
    respond_to do |format|
      if @product.update(product_params)
        format.html { redirect_to product_url(@product), notice: 'Product was successfully updated.' }
        format.json { render :show, status: :ok, location: @product }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @product.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /products/1 or /products/1.json
  def destroy
    @product.destroy

    respond_to do |format|
      format.html { redirect_to products_url, notice: 'Product was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_product
    @product = Product.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def product_params
    params.require(:product).permit(:name, :unit, :amount, :user_id)
  end

  def search_params
    params.permit(diet: {diet_set_ids: [], diet_set_quantities: {}})
  end
end
