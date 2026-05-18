# Browser-facing HTML pages reached from links in verification and
# password-reset emails. The rest of the app is a JSON API; these few pages
# exist purely so an email recipient has somewhere to land. The Phase 3
# frontend can later take these over by repointing AppUrl.
class PagesController < ActionController::Base
  layout 'pages'

  # The token in the URL is itself the secret credential, so a forged request
  # buys an attacker nothing; and this api_only app carries no session for
  # CSRF protection to hang off.
  skip_forgery_protection

  # GET /verify_email?token=...
  def verify_email
    user = find_by_token(:email_verification_token)
    if user
      user.verify_email!
      render :verify_email
    else
      render :verify_email_invalid, status: :unprocessable_entity
    end
  end

  # GET /reset_password?token=... — renders the new-password form.
  def reset_password_form
    @token = params[:token].to_s
    user = find_by_token(:password_reset_token)
    if user&.password_reset_valid?
      render :reset_password
    else
      render :reset_password_invalid, status: :unprocessable_entity
    end
  end

  # POST /reset_password — applies the new password from the form.
  def reset_password
    @token = params[:token].to_s
    user = find_by_token(:password_reset_token)

    unless user&.password_reset_valid?
      return render :reset_password_invalid, status: :unprocessable_entity
    end

    if user.reset_password!(params[:password].to_s)
      render :reset_password_done
    else
      @error = user.errors.full_messages.to_sentence
      render :reset_password, status: :unprocessable_entity
    end
  end

  private

  def find_by_token(column)
    token = params[:token].to_s
    return nil if token.blank?

    User.find_by(column => token)
  end
end
