class User < ApplicationRecord
  has_secure_password

  has_many :items, dependent: :destroy

  # A password-reset link is only usable for a short window after it is issued.
  PASSWORD_RESET_TTL = 2.hours

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true

  before_validation :normalize_email

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

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end
