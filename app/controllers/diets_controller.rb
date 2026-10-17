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

    if @diet.source == 'pdf'
      @diet.errors.add(:base, 'Plik musi być PDF-em o rozmiarze do 10 MB.') unless pdf_upload?(diet_params[:pdf])
      unless params.dig(:diet, :pii_confirmed) == '1'
        @diet.errors.add(:base, 'Potwierdź, że plik nie zawiera danych osobowych. Wybierz plik ponownie.')
      end
      unless Current.user.consented?(:parse_disclaimer) || params.dig(:diet, :parse_disclaimer) == '1'
        @diet.errors.add(:base, 'Zaakceptuj informację o automatycznym odczycie diety.')
      end
      if @diet.errors.any?
        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @diet.errors, status: :unprocessable_entity }
        end
        return
      end
      @diet.pii_confirmed_at = Time.current
    end

    # Art. 9 RODO: every AI operation needs the explicit health-data consent (wizard included, if re-enabled).
    if %w[pdf generated].include?(@diet.source) &&
       !(Current.user.consented?(:health_data) || params.dig(:diet, :health_data) == '1')
      @diet.errors.add(:base, 'Wyraź zgodę na przetwarzanie danych dotyczących zdrowia, aby wczytać dietę.')
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @diet.errors, status: :unprocessable_entity }
      end
      return
    end

    # Reserve (check + consume in one UPDATE) before anything is enqueued, so
    # parallel submissions cannot all pass a check and then each spend.
    ai_operation = %w[pdf generated].include?(@diet.source)
    if ai_operation && !Current.user.reserve_ai_quota!
      redirect_to new_diet_path, alert: ai_quota_exhausted_alert
      return
    end

    respond_to do |format|
      if @diet.save
        case @diet.source
        when 'pdf' then DietBuilderJob.perform_later(@diet.id)
        when 'generated' then GenerateDietJob.perform_later(@diet.id)
        end

        if @diet.source == 'pdf' && !Current.user.consented?(:parse_disclaimer)
          Current.user.record_consent!(:parse_disclaimer)
        end
        if %w[pdf generated].include?(@diet.source) && !Current.user.consented?(:health_data)
          Current.user.record_consent!(:health_data)
        end

        notice = {
          'pdf' => 'Dieta została utworzona. Produkty zostaną wczytane i zkategoryzowane.',
          'generated' => 'Dieta jest generowana przez AI. Za chwilę będzie gotowa.',
          'manual' => 'Dieta została utworzona. Dodaj dni i posiłki ręcznie.',
        }.fetch(@diet.source)

        format.html { redirect_to diets_path, notice: notice }
        format.json { render :new, status: :created, location: diets_path }
      else
        Current.user.refund_ai_quota! if ai_operation
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @diet.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
    @diet = Current.user.diets.find(params[:id])
  end

  # Owner-checked on every hit, unlike the permanent signed Active Storage url.
  def pdf
    diet = Current.user.diets.find(params[:id])
    return head :not_found unless diet.pdf.attached?

    send_data diet.pdf.download, filename: diet.pdf.filename.to_s, type: 'application/pdf', disposition: 'inline'
  end

  def update
    @diet = Current.user.diets.find(params[:id])

    respond_to do |format|
      if @diet.update(diet_params.except(:pdf)) # the file is only accepted through create (consents, quota, type check)
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
    diet = Current.user.diets.find(params[:id])
    diet.update(active: !diet.active)

    # Plain redirect for Turbo too: back to the same page it's a refresh, which the index morphs in place.
    redirect_to diets_path, status: :see_other,
                            notice: diet.active? ? 'Dieta została aktywowana.' : 'Dieta została dezaktywowana.'
  end

  def reparse
    @diet = Current.user.diets.find(params[:id])
    unless @diet.pdf.attached?
      redirect_to diets_path, alert: 'Brak załączonego PDF. Nie można przeparsować diety.'
      return
    end

    unless Current.user.consented?(:health_data)
      redirect_to profile_path, alert: 'Aby przetworzyć dietę, wyraź zgodę na przetwarzanie danych dotyczących zdrowia.'
      return
    end

    unless params[:pii_confirmed] == '1'
      redirect_to diets_path, alert: 'Potwierdź, że PDF nie zawiera danych osobowych, aby przeparsować dietę.'
      return
    end

    # Block a second parse while one runs, but let the user unstick a diet a
    # killed worker left in "generating" for good.
    if @diet.generating? && @diet.updated_at > Diet::STUCK_GENERATING_AFTER.ago
      redirect_to diets_path, alert: 'Ta dieta jest właśnie wczytywana. Poczekaj, aż się zakończy.'
      return
    end

    unless Current.user.reserve_ai_quota!
      redirect_to diets_path, alert: ai_quota_exhausted_alert
      return
    end

    # Conditional flip: a concurrent reparse of the same diet gets 0 rows and its reservation back.
    now = Time.current
    flipped = Diet.where(id: @diet.id)
      .where('status != ? OR updated_at < ?', 'generating', Diet::STUCK_GENERATING_AFTER.ago)
      .update_all(status: 'generating', generation_error: nil, pii_confirmed_at: now, updated_at: now) # rubocop:disable Rails/SkipsModelValidations
    if flipped.zero?
      Current.user.refund_ai_quota!
      redirect_to diets_path, alert: 'Ta dieta jest właśnie wczytywana. Poczekaj, aż się zakończy.'
      return
    end

    DietBuilderJob.perform_later(@diet.id)
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
