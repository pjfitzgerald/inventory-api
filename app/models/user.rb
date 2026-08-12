class User < ApplicationRecord
  has_secure_password

  # Items this user created. They live in an inventory, not on the user, so
  # deleting the account leaves anything they added to a shared inventory in
  # place — it just loses its author.
  has_many :items, dependent: :nullify

  has_many :inventory_memberships, dependent: :destroy
  has_many :inventories, through: :inventory_memberships
  has_many :owned_inventories, class_name: 'Inventory',
                               foreign_key: :owner_id,
                               dependent: :destroy,
                               inverse_of: :owner

  # A password-reset link is only usable for a short window after it is issued.
  PASSWORD_RESET_TTL = 2.hours

  # Length is the control that actually matters (NIST SP 800-63B); character
  # class rules mostly push people towards "Password1!". The maximum isn't
  # arbitrary — bcrypt silently truncates at 72 bytes, so anything longer
  # would make the tail of the password meaningless rather than rejected.
  PASSWORD_MIN_LENGTH = 10
  PASSWORD_MAX_LENGTH = 72

  # A blocklist can't be exhaustive; this just catches the handful of
  # passwords that dominate credential-stuffing lists. Matched both literally
  # and with case plus any trailing digits/punctuation stripped, so
  # "Password123!" is caught as well as "password".
  COMMON_PASSWORDS = %w[
    password passw0rd pass letmein welcome monkey dragon iloveyou admin
    administrator qwerty qwertyuiop asdfgh zxcvbn abcdef abc123 123456
    1234567890 football baseball sunshine princess trustno1 starwars
    inventory changeme secret
  ].freeze

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password,
            length: { minimum: PASSWORD_MIN_LENGTH, maximum: PASSWORD_MAX_LENGTH },
            allow_nil: true
  validate :password_is_not_obvious

  before_validation :normalize_email

  # Accounts created through signup get their inventory here. Fixtures and any
  # rows inserted straight into the table skip callbacks, so `personal_inventory`
  # also creates one on demand.
  after_create :ensure_personal_inventory!

  # The inventory a user gets by default and cannot delete or leave.
  def personal_inventory
    inventories.personal.first || ensure_personal_inventory!
  end

  def ensure_personal_inventory!
    inventories.personal.first ||
      Inventory.create!(name: 'Personal', owner: self, personal: true)
  end

  # Issue a fresh verification token; caller is responsible for saving.
  def start_email_verification!
    update!(email_verification_token: SecureRandom.urlsafe_base64(32),
            email_verified_at: nil)
  end

  def verify_email!
    update!(email_verified_at: Time.current, email_verification_token: nil)
  end

  def email_verified?
    email_verified_at.present?
  end

  # Issue a fresh password-reset token and stamp the time it was sent.
  def start_password_reset!
    update!(password_reset_token: SecureRandom.urlsafe_base64(32),
            password_reset_sent_at: Time.current)
  end

  # A reset token is only valid if one was issued and the TTL has not lapsed.
  def password_reset_valid?
    password_reset_sent_at.present? &&
      password_reset_sent_at > PASSWORD_RESET_TTL.ago
  end

  # Apply a new password from the reset flow. Possession of the reset token
  # (emailed to the address) also proves control of the inbox, so this marks
  # the email verified — otherwise a user who lost their verification email
  # would reset their password and still be unable to log in.
  # Returns true on success, false if the new password fails validation.
  def reset_password!(new_password)
    self.password = new_password
    self.email_verified_at ||= Time.current
    self.email_verification_token = nil
    self.password_reset_token = nil
    self.password_reset_sent_at = nil
    save
  end

  private

  # Reject the passwords an attacker would try first: known-common ones, and
  # anything derived from the account's own email address (which is the one
  # string an attacker is guaranteed to already have).
  def password_is_not_obvious
    return if password.blank?

    # Check the password as typed, and again with case and any trailing
    # digits/punctuation stripped, so the usual dodges — "Password1",
    # "monkey2024", "letmein!" — are recognised as the common passwords they
    # are, while all-numeric entries still match literally.
    downcased = password.downcase
    candidates = [downcased, downcased.sub(/[^a-z]+\z/, '')]

    if candidates.any? { |candidate| COMMON_PASSWORDS.include?(candidate) }
      errors.add(:password, 'is too common — pick something less guessable')
      return
    end

    local_part = email.to_s.split('@').first.to_s
    if local_part.length >= 3 && password.downcase.include?(local_part.downcase)
      errors.add(:password, 'must not contain your email address')
    end
  end

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end
