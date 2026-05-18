class UserMailer < ApplicationMailer
  # Sent on signup; the link verifies the address and unblocks login.
  def verification_email(user)
    @user = user
    @url = AppUrl.verify_email(user.email_verification_token)
    mail(to: user.email, subject: 'Verify your inventory account')
  end

  # Sent on a password-reset request; the link opens the reset form.
  def password_reset_email(user)
    @user = user
    @url = AppUrl.reset_password(user.password_reset_token)
    @ttl_hours = (User::PASSWORD_RESET_TTL / 1.hour).to_i
    mail(to: user.email, subject: 'Reset your inventory password')
  end
end
