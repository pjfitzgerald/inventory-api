# Soft delete. DELETE /items/:id now stamps `deleted_at` instead of removing
# the row, which is what makes both the undo popup and the recycle bin
# possible — an undo that had to re-POST the item would come back with a new
# id, losing its history and any references to it.
#
# Every read path filters on `deleted_at IS NULL`, so the partial index covers
# exactly that: it stays small (the bin is expected to be near-empty) and is
# the one the item list actually uses.
class AddDeletedAtToItems < ActiveRecord::Migration[7.0]
  def change
    add_column :items, :deleted_at, :datetime

    add_index :items, %i[inventory_id updated_at],
              where: 'deleted_at IS NULL',
              name: 'index_items_live_on_inventory'
    add_index :items, :deleted_at, where: 'deleted_at IS NOT NULL',
                                   name: 'index_items_on_deleted_at'
  end
end
