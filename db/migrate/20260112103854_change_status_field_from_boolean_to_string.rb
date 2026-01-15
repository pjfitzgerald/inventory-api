class ChangeStatusFieldFromBooleanToString < ActiveRecord::Migration[7.0]
  def up
    # Remove the old boolean column
    remove_column :items, :potential_discard_sell

    # Add new string column for status (Keep/Sell/Discard)
    add_column :items, :status, :string, default: 'Keep'
  end

  def down
    remove_column :items, :status
    add_column :items, :potential_discard_sell, :boolean
  end
end
