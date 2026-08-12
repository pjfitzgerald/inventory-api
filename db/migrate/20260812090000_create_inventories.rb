class CreateInventories < ActiveRecord::Migration[7.0]
  # Items move from "owned by a user" to "held in an inventory that users are
  # members of". Every existing user gets a personal inventory holding
  # everything they already had, so the change is invisible until someone
  # actually shares something.
  def up
    create_table :inventories do |t|
      t.string :name, null: false
      t.references :owner, null: false, foreign_key: { to_table: :users }
      # Exactly one inventory per user is their undeletable personal one.
      t.boolean :personal, null: false, default: false
      t.timestamps
    end

    add_index :inventories, :owner_id, unique: true,
                                       where: 'personal',
                                       name: 'index_inventories_on_one_personal_per_owner'

    create_table :inventory_memberships do |t|
      t.references :inventory, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false, default: 'editor'
      t.timestamps
    end

    add_index :inventory_memberships, %i[inventory_id user_id], unique: true,
                                                                name: 'index_memberships_on_inventory_and_user'

    add_reference :items, :inventory, foreign_key: true, index: true

    backfill_personal_inventories

    change_column_null :items, :inventory_id, false

    # An item's user_id now records who created it, not who may see it. If that
    # account goes away the item stays with the inventory, so the column has to
    # be nullable.
    change_column_null :items, :user_id, true
  end

  def down
    remove_reference :items, :inventory, foreign_key: true
    drop_table :inventory_memberships
    drop_table :inventories
    # items.user_id is left nullable — re-tightening it could fail on rows
    # whose creator has since been deleted.
  end

  private

  # Raw SQL rather than the models: a migration has to keep working after the
  # model layer moves on.
  def backfill_personal_inventories
    users = select_all('SELECT id, name, email FROM users ORDER BY id').to_a
    say "Creating a personal inventory for #{users.size} user(s)"

    users.each do |user|
      inventory_id = select_value(<<~SQL)
        INSERT INTO inventories (name, owner_id, personal, created_at, updated_at)
        VALUES ('Personal', #{user['id']}, TRUE, NOW(), NOW())
        RETURNING id
      SQL

      execute(<<~SQL)
        INSERT INTO inventory_memberships (inventory_id, user_id, role, created_at, updated_at)
        VALUES (#{inventory_id}, #{user['id']}, 'owner', NOW(), NOW())
      SQL

      execute(<<~SQL)
        UPDATE items SET inventory_id = #{inventory_id} WHERE user_id = #{user['id']}
      SQL
    end

    orphans = select_value('SELECT COUNT(*) FROM items WHERE inventory_id IS NULL').to_i
    raise "#{orphans} item(s) could not be placed in an inventory" if orphans.positive?
  end
end
