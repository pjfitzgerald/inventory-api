module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :authenticate!,
                          only: %i[signup login verify logout
                                   request_password_reset reset_password]

      # POST /api/v1/auth/signup
      def signup
        user = User.new(
          email: params[:email],
          password: params[:password],
          name: params[:name],
          email_verification_token: SecureRandom.urlsafe_base64(32)
        )

        if user.save
          deliver(UserMailer.verification_email(user))
          render json: {
            user: user_json(user),
            message: 'Account created. Check your email for a verification link.',
            # Emailed to the user; also surfaced in the response when tokens
            # are exposed (dev/test always, staging via EXPOSE_AUTH_TOKENS) so
            # the CLI / staging UI can complete the flow without a real inbox.
            verification_token: (user.email_verification_token if auth_tokens_exposed?)
          }.compact, status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/auth/login
      def login
        user = User.find_by(email: params[:email].to_s.strip.downcase)

        unless user&.authenticate(params[:password].to_s)
          return render json: { error: 'Invalid email or password' }, status: :unauthorized
        end

        unless user.email_verified?
          return render json: { error: 'Email not verified — check your inbox for the verification link' },
                        status: :forbidden
        end

        render json: { token: JsonWebToken.encode({ user_id: user.id }), user: user_json(user) }
      end

      # POST /api/v1/auth/verify
      def verify
        token = params[:token].to_s
        user = token.present? && User.find_by(email_verification_token: token)

        unless user
          return render json: { error: 'Invalid or expired verification token' },
                        status: :unprocessable_entity
        end

        user.verify_email!
        render json: {
          token: JsonWebToken.encode({ user_id: user.id }),
          user: user_json(user),
          message: 'Email verified.'
        }
      end

      # POST /api/v1/auth/request_password_reset
      def request_password_reset
        user = User.find_by(email: params[:email].to_s.strip.downcase)
        if user
          user.start_password_reset!
          deliver(UserMailer.password_reset_email(user))
        end

        # Identical response whether or not the email exists, so this endpoint
        # can't be used to probe which addresses have accounts.
        render json: {
          message: 'If that email has an account, a password reset link is on its way.',
          reset_token: (user&.password_reset_token if auth_tokens_exposed?)
        }.compact
      end

      # POST /api/v1/auth/reset_password
      def reset_password
        token = params[:token].to_s
        user = token.present? && User.find_by(password_reset_token: token)

        unless user && user.password_reset_valid?
          return render json: { error: 'Invalid or expired reset token' },
                        status: :unprocessable_entity
        end

        if user.reset_password!(params[:password].to_s)
          render json: {
            token: JsonWebToken.encode({ user_id: user.id }),
            user: user_json(user),
            message: 'Password updated.'
          }
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/auth/logout — stateless: the client discards its token.
      def logout
        render json: { message: 'Logged out' }
      end

      # GET /api/v1/auth/me
      def me
        render json: { user: user_json(current_user) }
      end

      private

      # Send mail without letting a delivery failure break the request: the
      # account change has already been persisted and matters more than the
      # email going out. Failures are logged for follow-up.
      def deliver(mail)
        mail.deliver_now
      rescue StandardError => e
        Rails.logger.error("Email delivery failed: #{e.class}: #{e.message}")
      end

      # Whether the verification / reset tokens are returned in the JSON
      # response. Always true outside production; in production, gated on
      # the EXPOSE_AUTH_TOKENS env var (set on staging so the UI flows are
      # testable without real email delivery).
      def auth_tokens_exposed?
        !Rails.env.production? || ENV['EXPOSE_AUTH_TOKENS'] == 'true'
      end

      def user_json(user)
        {
          id: user.id,
          email: user.email,
          name: user.name,
          email_verified: user.email_verified?
        }
      end
    end
  end
end
