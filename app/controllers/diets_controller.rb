# frozen_string_literal: true

require 'pdf/reader'

class DietsController < ApplicationController
  def index
    @diets = Current.user.diets.order(created_at: :desc)
  end

  def show
    @diet = Current.user.diets.find(params[:id])

    products = if params[:diet].present?
      @diet.products.joins(:meal).where(meals: { diet_set_id: search_params[:diet_set_ids] })
              else
                @diet.products
    end

    @products = Product.group_and_sum_by_name_then_category(products)
  end

  def search
    @diet = Current.user.diets.find(params[:id])
    products = @diet.products.joins(:meal).where(meals: { diet_set_id: search_params[:diet_set_ids] })
    @products = Product.group_and_sum_by_name_then_category(products)
  end

  def new
    @diet = Diet.new
  end

  def create
    @diet = Diet.new(diet_params.slice(:name, :active).merge(user: Current.user))

    if diet_params[:pdf].present?
      @diet.source = 'pdf'
      @diet.status = 'generating'
      @diet.pdf = diet_params[:pdf]
      @diet.meals_per_day = diet_params[:meals_per_day]
    elsif diet_params[:kcal_target].present?
      slots = Array(params.dig(:diet, :slots)).reject(&:blank?)
      slots = %w[breakfast lunch dinner] if slots.empty?

      goal = Diet::GOAL_MACROS.key?(diet_params[:goal]) ? diet_params[:goal] : 'zwykla'

      @diet.source = 'generated'
      @diet.status = 'generating'
      @diet.kcal_target = diet_params[:kcal_target]
      @diet.meals_per_day = slots.size
      @diet.generation_prefs = {
        'days_count' => diet_params[:days_count].presence&.to_i || 1,
        'slots' => slots,
        'goal' => goal,
        'macro_split' => Diet::GOAL_MACROS.fetch(goal).slice('protein_pct', 'fat_pct', 'carbs_pct'),
        'preferences' => diet_params[:preferences],
      }
    else
      @diet.source = 'manual'
    end

    unless Diet::CREATION_MODES.include?(@diet.source)
      @diet.errors.add(:base, 'Wybierz plik PDF z dietą.')
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @diet.errors, status: :unprocessable_entity }
      end
      return
    end

    if %w[pdf generated].include?(@diet.source) && !Current.user.ai_quota_available?
      redirect_to new_diet_path, alert: 'Wykorzystałeś darmową operację AI w tym miesiącu. Przejdź na Pro, aby kontynuować.'
      return
    end

    respond_to do |format|
      if @diet.save
        case @diet.source
        when 'pdf' then DietBuilderJob.perform_later(@diet.id)
        when 'generated' then GenerateDietJob.perform_later(@diet.id)
        end

        Current.user.consume_ai_quota! if %w[pdf generated].include?(@diet.source)

        notice = {
          'pdf' => 'Dieta została utworzona. Produkty zostaną wczytane i zkategoryzowane.',
          'generated' => 'Dieta jest generowana przez AI. Za chwilę będzie gotowa.',
          'manual' => 'Dieta została utworzona. Dodaj dni i posiłki ręcznie.',
        }.fetch(@diet.source)

        format.html { redirect_to diets_path, notice: notice }
        format.json { render :new, status: :created, location: diets_path }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @diet.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
    @diet = Current.user.diets.find(params[:id])
  end

  def update
    @diet = Current.user.diets.find(params[:id])

    respond_to do |format|
      if @diet.update(diet_params)
        format.html { redirect_to diets_path, notice: 'Diet was successfully updated.' }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    diet = Current.user.diets.find(params[:id])
    respond_to do |format|
      if diet.destroy
        format.html { redirect_to diets_path, notice: 'Dieta została usunięta.' }
      else
        format.html { render :index, status: :unprocessable_entity }
      end
    end
  end

  def toggle_active
    @diet = Current.user.diets.find(params[:id])
    @diet.update(active: !@diet.active)
    @diet.reload

    respond_to do |format|
      format.html { redirect_to diets_path, notice: @diet.active? ? 'Dieta została aktywowana.' : 'Dieta została dezaktywowana.' }
      format.turbo_stream do
        flash.now[:notice] = @diet.active? ? 'Dieta została aktywowana.' : 'Dieta została dezaktywowana.'
        render :toggle_active
      end
    end
  end

  def reparse
    @diet = Current.user.diets.find(params[:id])
    unless @diet.pdf.attached?
      redirect_to diets_path, alert: 'Brak załączonego PDF. Nie można przeparsować diety.'
      return
    end

    unless Current.user.ai_quota_available?
      redirect_to diets_path, alert: 'Wykorzystałeś darmową operację AI w tym miesiącu. Przejdź na Pro, aby kontynuować.'
      return
    end

    @diet.update!(status: 'generating', generation_error: nil)
    DietBuilderJob.perform_later(@diet.id)
    Current.user.consume_ai_quota!
    redirect_to diets_path, notice: 'Przeparsowanie diety zostało uruchomione. Zestawy i posiłki zostaną odtworzone z PDF (przetwarzanie w tle).'
  end

  private

  def search_params
    params.require(:diet).permit(diet_set_ids: [])
  end

  def diet_params
    params.require(:diet).permit(
      :pdf, :name, :active, :meals_per_day,
      :kcal_target, :days_count, :goal, :preferences
    )
  end
end
