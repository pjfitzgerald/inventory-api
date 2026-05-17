class User < ApplicationRecord
  has_secure_password

  has_many :items, dependent: :destroy

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

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end
