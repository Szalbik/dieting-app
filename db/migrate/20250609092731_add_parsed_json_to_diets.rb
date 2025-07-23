class AddParsedJsonToDiets < ActiveRecord::Migration[8.0]
  def change
    add_column :diets, :parsed_json, :text
  end
end
