require 'bcrypt'

class AddUserToItems < ActiveRecord::Migration[7.0]
  def up
    add_reference :items, :user, foreign_key: true, index: true

    orphans = select_value('SELECT COUNT(*) FROM items WHERE user_id IS NULL').to_i
    if orphans.positive?
      say "Backfilling #{orphans} pre-auth item(s) to an owner account"
      execute "UPDATE items SET user_id = #{backfill_owner_id} WHERE user_id IS NULL"
    end

    change_column_null :items, :user_id, false
  end

  def down
    remove_reference :items, :user, foreign_key: true
  end

  private

  # Pre-auth items need an owner. Reuse the first existing user, or create
  # a single owner account to hold them. Its password is random — claim the
  # account with `rails 'auth:set_password[email,password]'`.
  def backfill_owner_id
    existing = select_value('SELECT id FROM users ORDER BY id LIMIT 1')
    return existing if existing

    email = quote(ENV.fetch('BACKFILL_OWNER_EMAIL', 'owner@example.com'))
    digest = quote(BCrypt::Password.create(SecureRandom.hex(32)))
    execute(<<~SQL)
      INSERT INTO users (email, password_digest, name, email_verified_at, created_at, updated_at)
      VALUES (#{email}, #{digest}, 'Inventory Owner', NOW(), NOW(), NOW())
    SQL
    select_value("SELECT id FROM users WHERE email = #{email}")
  end
end
