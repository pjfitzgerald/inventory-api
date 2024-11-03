class CreateItems < ActiveRecord::Migration[7.0]
  def change
    create_table :items do |t|
      t.integer :quantity
      t.string :category
      t.string :tags
      t.string :current_location
      t.decimal :weight
      t.string :owner
      t.string :intended_location
      t.text :notes
      t.text :location_notes
      t.boolean :potential_discard_sell
      t.string :name

      t.timestamps
    end
  end
end
