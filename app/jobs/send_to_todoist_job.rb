# frozen_string_literal: true

class SendToTodoistJob < ApplicationJob
  queue_as :default

  def perform(project_id, diet_set_ids, diet_set_quantities, token, user_id)
    # Step 1: Filter products based on selected diet sets
    selected_diet_set_ids = diet_set_ids.reject(&:empty?) rescue []
    user = User.find(user_id)
    products = user.active_products.where(diet_set_id: selected_diet_set_ids)

    # Step 2: Prepare products with quantities
    multiplied_products = []
    if diet_set_quantities.present?
      diet_set_quantities.each do |diet_set_id, quantity|
        next unless selected_diet_set_ids.include?(diet_set_id)

        quantity = quantity.to_i
        # Assuming each product should be duplicated based on the quantity
        products.where(diet_set_id: diet_set_id).each do |product|
          quantity.times { multiplied_products << product }
        end
      end
    else
      multiplied_products = products
    end

    grouped_products = Product.group_and_sum_by_name_and_unit(multiplied_products)

    sections = Todoist::Api.fetch_sections(token, project_id)

    categories_with_section_ids = Category.all.map.each do |category|
      section = sections.find { |s| s['name'] == category.name }

      if section.present?
        section.merge(category_id: category.id).symbolize_keys!
      else
        Todoist::Api.create_section(category, token, project_id).symbolize_keys!
      end
    end

    response = Todoist::Api.create_task(grouped_products, categories_with_section_ids, token, project_id)

    diets = user.active_diets.select { |diet| diet.diet_sets.where(id: selected_diet_set_ids).present? }
    diets.each do |diet|
      diet_sets_names = diet.diet_sets.where(id: selected_diet_set_ids).pluck(:name).join(', ')
      diet.audit_logs.create(action: 'create', description: "Sent products to Todoist #{diet.name} diet with sets: #{diet_sets_names}")
    end
  end
end
