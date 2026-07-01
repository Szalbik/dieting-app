class AddGenerationFieldsToDiets < ActiveRecord::Migration[8.0]
  def change
    add_column :diets, :source, :string, default: 'pdf', null: false
    add_column :diets, :kcal_target, :integer
    add_column :diets, :generation_prefs, :text
  end
end
