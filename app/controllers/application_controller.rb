class ApplicationController < ActionController::API
  include ActionController::MimeResponds

  before_action :authenticate!

  attr_reader :current_user

  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: 'Not found' }, status: :not_found
  end

  private

  def authenticate!
    @current_user = user_from_token
    render_unauthorized unless @current_user
  end

  def user_from_token
    payload = JsonWebToken.decode(bearer_token)
    return nil unless payload

    User.find_by(id: payload[:user_id])
  end

  def bearer_token
    request.headers['Authorization']&.match(/\ABearer (.+)\z/)&.captures&.first
  end

  def render_unauthorized(message = 'Not authenticated')
    render json: { error: message }, status: :unauthorized
  end
end
