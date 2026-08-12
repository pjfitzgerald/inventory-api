class ApplicationController < ActionController::API
  include ActionController::MimeResponds

  before_action :authenticate!

  attr_reader :current_user

  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: 'Not found' }, status: :not_found
  end

  private

  # Every inventory the current user can see, whether their own or shared
  # with them. All item lookups go through this, so an id from another
  # account's inventory simply isn't found.
  def accessible_inventories
    Inventory.where(id: current_user.inventory_memberships.select(:inventory_id))
  end

  # The inventory a request acts on: the one asked for, or the user's personal
  # one. Not a member (or no such inventory) is a 404, not a 403 — there is no
  # reason to confirm that someone else's inventory exists.
  def current_inventory
    @current_inventory ||=
      if params[:inventory_id].present?
        accessible_inventories.find(params[:inventory_id])
      else
        current_user.personal_inventory
      end
  end

  def current_membership
    @current_membership ||= current_inventory.membership_for(current_user)
  end

  def require_edit_access!
    return if current_membership&.can_edit_items?

    render json: { error: 'You have view-only access to this inventory' },
           status: :forbidden
  end

  def require_manage_access!
    return if current_membership&.can_manage?

    render json: { error: 'Only the owner can manage this inventory' },
           status: :forbidden
  end

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
