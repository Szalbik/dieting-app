# frozen_string_literal: true

# A class to represent a diet
class Diet < ApplicationRecord
  belongs_to :user, optional: true
  has_many :diet_sets, dependent: :destroy
  has_many :meals, through: :diet_sets
  has_many :products, through: :meals
  has_many :diet_set_plans, through: :diet_sets
  has_many :audit_logs, as: :trackable, dependent: :destroy
  has_one_attached :pdf, dependent: :destroy

  # Index/show subscribe to [user, :diets]; a status flip from the background
  # parse morphs the page in place (Turbo 8 refresh), no polling.
  broadcasts_refreshes_to ->(diet) { [diet.user, :diets] }

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :meals_per_day, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 10 }, allow_nil: true
  validates :source, inclusion: { in: %w[pdf generated manual] }
  validates :kcal_target, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :status, inclusion: { in: %w[generating ready failed] }

  # ponytail: launch toggle — add 'generated'/'manual' back to re-enable the AI wizard and blank diets.
  CREATION_MODES = %w[pdf].freeze

  # ponytail: starter macro ratios per goal, not personalized (age/weight/activity) —
  # tune from real generated plans once we have usage data.
  GOAL_MACROS = {
    'zwykla' => {
      'protein_pct' => 25, 'fat_pct' => 30, 'carbs_pct' => 45,
                  'label' => 'Zwykła / zbilansowana', 'hint' => 'Standardowe proporcje, bez konkretnego celu sylwetkowego.'
    },
    'masa' => {
      'protein_pct' => 35, 'fat_pct' => 25, 'carbs_pct' => 40,
                'label' => 'Na siłownię (budowanie mięśni)', 'hint' => 'Więcej białka i węglowodanów, wsparcie treningu i regeneracji.'
    },
    'redukcja' => {
      'protein_pct' => 40, 'fat_pct' => 30, 'carbs_pct' => 30,
                    'label' => 'Odchudzanie / redukcja', 'hint' => 'Więcej białka, mniej węglowodanów — sprzyja utracie tkanki tłuszczowej.'
    },
    'utrzymanie' => {
      'protein_pct' => 25, 'fat_pct' => 30, 'carbs_pct' => 45,
                       'label' => 'Utrzymaniowa', 'hint' => 'Stabilizacja obecnej wagi.'
    },
  }.freeze

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  # Longer than any observed parse (14-day plan p95 ≈ 2 min); past this a
  # "generating" diet is assumed orphaned by a dead worker and may be reparsed.
  STUCK_GENERATING_AFTER = 30.minutes

  def generating?
    status == 'generating'
  end

  # Shared by DietBuilderJob / GenerateDietJob / PopulateDietFromJsonJob:
  # mark failed and give the AI op back — only on the generating→failed
  # transition, so a manual job retry can't refund twice.
  def fail_generation!(error)
    refund = generating?
    update!(status: 'failed', generation_error: error.message.to_s.truncate(1000))
    user&.refund_ai_quota! if refund
  end

  def failed?
    status == 'failed'
  end

  attribute :generation_prefs, :json, default: {}

  def classify_products!
    return unless products.any?

    products.each do |product|
      next if product.category.present?

      prediction = Classifier::Category.predict(product.name)
      next if prediction[:name].blank?

      category = Category.find_by(name: prediction[:name])
      next if category.blank?

      ProductCategory.create!(
        category: category,
        product: product,
        state: prediction[:state]
      )
    end

    # Last-resort AI fallback for whatever the local classifier couldn't place —
    # one batched call for the whole diet, not per-product.
    Chat::ProductCategorizerService.new(products: products.uncategorized).call
  end

  attribute :parsed_json, :json, default: {}

  def parse_pdf_content_with_chat!
    return unless pdf.attached?

    temp_path = Tempfile.new(['diet_pdf', '.pdf'])

    pdf.open do |file|
      IO.copy_stream(file, temp_path.path)
    end

    begin
      parsed_data = Chat::DietParserService.new(
        temp_path.path,
        expected_meals_per_day: meals_per_day
      ).call
      # Możesz teraz zapisać JSON do atrybutu, np. `parsed_json`:
      update!(parsed_json: parsed_data)
    rescue JSON::ParserError => e
      Rails.logger.error("JSON parsing error for diet #{id}: #{e.message}")
      raise "Błąd parsowania JSON: #{e.message}"
    rescue => e
      # DietJsonValidationError lives in diet_json_validator.rb, so naming it in a
      # rescue clause NameErrors under lazy loading (dev/test); duck-type instead.
      Rails.logger.error("Błąd przetwarzania diety #{id}: #{e.message}")
      Rails.logger.error("Validation errors: #{e.errors.inspect}") if e.respond_to?(:errors)
      Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
      raise e
    ensure
      temp_path.close
      temp_path.unlink
    end
  end
end
