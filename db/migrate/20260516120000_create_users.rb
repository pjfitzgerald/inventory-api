class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    enable_extension 'citext' unless extension_enabled?('citext')

    create_table :users do |t|
      t.citext :email, null: false
      t.string :password_digest, null: false
      t.string :name
      t.datetime :email_verified_at
      t.string :email_verification_token

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :email_verification_token, unique: true
  end
end
