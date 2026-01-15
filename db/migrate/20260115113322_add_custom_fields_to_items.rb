class AddCustomFieldsToItems < ActiveRecord::Migration[7.0]
  def change
    add_column :items, :custom_fields, :jsonb, default: {}
  end
end
