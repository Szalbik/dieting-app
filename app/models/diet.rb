# frozen_string_literal: true

# A class to represent a diet
class Diet < ApplicationRecord
  belongs_to :user, optional: true
  has_many :diet_sets, dependent: :destroy
  has_many :meals, through: :diet_sets
  has_many :products, through: :meals
  has_many :meal_plans, through: :diet_sets
  has_many :audit_logs, as: :trackable, dependent: :destroy
  has_one_attached :pdf, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :user_id }

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  def classify_products!
    return unless products.any?

    products.each do |product|
      product_category = Classifier::Category.predict(product.name)
      ProductCategory.create(
        category: Category.find_by(name: product_category[:name]),
        product: product,
        state: product_category[:state]
      )
    end
  end

  # def categorize_products!
  #   return unless products.any?

  #   batch_size = 15
  #   offset = 0

  #   loop do
  #     products_batch = products.includes(:product_category).offset(offset).limit(batch_size)
  #     break if products_batch.empty?

  #     products_without_categories = products_batch.where(product_categories: { id: nil })
  #     # Use products_with_categories as needed (e.g., display, process, etc.)

  #     if products_without_categories.any?
  #       Chat::CategorizeProducts.call(products: products_without_categories, diet: self)
  #     else
  #       break
  #     end

  #     offset += batch_size
  #   end
  # end

  def parse_pdf_content!
    return unless pdf.attached?

    # ActiveRecord::Base.transaction do
    builder = DietBuilder.new(self)

    pdf.open do |file|
      PDF::Reader.open(file) do |reader|
        reader.pages.each do |page|
          builder.process_page(page)
        end
      end
    end

    builder.save_ingredients
    # end
  end
end
