# frozen_string_literal: true

require 'pdf/reader'

class DietsController < ApplicationController
  def index
    if params[:active].present? && params[:active] == 'false'
      return @diets = Current.user.diets.inactive
    end

    @diets = Current.user.diets.active
  end

  def show
    @diet = Diet.find(params[:id])

    products = if params[:diet].present?
      @diet.products.where(diet_set_id: search_params[:diet_set_ids])
              else
                @diet.products
    end

    @products = Product.group_and_sum_by_name_and_unit(products)
  end

  def search
    @diet = Diet.find(params[:id])
    products = @diet.products.where(diet_set_id: search_params[:diet_set_ids])
    @products = Product.group_and_sum_by_name_and_unit(products)
  end

  def new
    @diet = Diet.new
  end

  def create
    @diet = Diet.new(diet_params.merge(user: Current.user))

    respond_to do |format|
      if @diet.save
        DietBuilderJob.perform_later(@diet.id)
        format.html { redirect_to diets_path, notice: 'Dieta została utworzona. Produkty zostaną wczytane i zkategoryzowane.' }
        format.json { render :new, status: :created, location: diets_path }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @diet.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
    @diet = Diet.find(params[:id])
  end

  def update
    @diet = Diet.find(params[:id])

    respond_to do |format|
      if @diet.update(diet_params)
        format.html { redirect_to diets_path, notice: 'Diet was successfully updated.' }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    diet = Diet.find(params[:id])
    respond_to do |format|
      if diet.destroy
        format.html { redirect_to diets_path, notice: 'Dieta została usunięta.' }
      else
        format.html { render :index, status: :unprocessable_entity }
      end
    end
  end

  private

  def search_params
    params.require(:diet).permit(diet_set_ids: [])
  end

  def diet_params
    params.require(:diet).permit(:pdf, :name)
  end
end
