class SendToTodoistJob < ApplicationJob
  queue_as :default

  def perform(project_id, diet_set_ids, token, user_id)
    products = Product.where(diet_set_id: diet_set_ids)
    grouped_products = Product.group_and_sum_by_name_and_unit(products)

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

    diets = User.find(user_id).active_diets.select{ |diet| diet.diet_sets.where(id: diet_set_ids).present? }
    diets.each do |diet|
      diet_sets_names = diet.diet_sets.where(id: diet_set_ids).pluck(:name).join(', ')
      diet.audit_logs.create(action: 'create', description: "Sent products to Todoist #{diet.name} diet with sets: #{diet_sets_names}")
    end
  end
end
