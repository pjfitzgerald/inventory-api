module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :authenticate!, only: %i[signup login verify logout]

      # POST /api/v1/auth/signup
      def signup
        user = User.new(
          email: params[:email],
          password: params[:password],
          name: params[:name],
          email_verification_token: SecureRandom.urlsafe_base64(32)
        )

        if user.save
          render json: {
            user: user_json(user),
            message: 'Account created. Verify your email address to log in.',
            # Emailed in production; surfaced directly until email delivery lands.
            verification_token: (user.email_verification_token unless Rails.env.production?)
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

      # POST /api/v1/auth/logout — stateless: the client discards its token.
      def logout
        render json: { message: 'Logged out' }
      end

      # GET /api/v1/auth/me
      def me
        render json: { user: user_json(current_user) }
      end

      private

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
