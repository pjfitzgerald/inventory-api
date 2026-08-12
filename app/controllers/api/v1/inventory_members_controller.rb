module Api
  module V1
    # Membership of a shared inventory. Invites go to accounts that already
    # exist and have verified their email — there is no pending-invite state
    # and nothing is emailed.
    class InventoryMembersController < ApplicationController
      # `current_inventory` reads :inventory_id, which is exactly the nested
      # route parameter here.
      before_action :require_manage_access!, only: %i[create update]
      before_action :load_membership, only: %i[update destroy]

      # Any member can see who else is in the inventory.
      def index
        memberships = current_inventory.inventory_memberships.includes(:user).order(:created_at)
        render json: memberships.map { |membership| serialize(membership) }
      end

      def create
        if current_inventory.personal?
          return render json: { error: 'Your personal inventory cannot be shared. Create a shared inventory instead.' },
                        status: :unprocessable_entity
        end

        user = User.find_by(email: params[:email].to_s.strip.downcase)

        # Deliberately explicit: this is an invite to a named colleague, not a
        # login form, so "no such account" is the useful answer rather than an
        # account-enumeration risk worth hiding.
        if user.nil?
          return render json: { error: "No account found for that email address. They need to sign up first." },
                        status: :not_found
        end

        unless user.email_verified?
          return render json: { error: 'That account has not verified its email address yet' },
                        status: :unprocessable_entity
        end

        membership = current_inventory.inventory_memberships.new(user: user, role: requested_role)

        if membership.save
          render json: serialize(membership), status: :created
        else
          render json: { errors: membership.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      def update
        if @membership.owner?
          return render json: { error: "The owner's role cannot be changed" },
                        status: :unprocessable_entity
        end

        if @membership.update(role: requested_role)
          render json: serialize(@membership)
        else
          render json: { errors: @membership.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      # Removing a member, or leaving an inventory yourself.
      def destroy
        if @membership.owner?
          return render json: { error: 'The owner cannot be removed. Delete the inventory instead.' },
                        status: :unprocessable_entity
        end

        unless current_membership&.can_manage? || @membership.user_id == current_user.id
          return render json: { error: 'Only the owner can remove other members' },
                        status: :forbidden
        end

        @membership.destroy
        head :no_content
      end

      private

      def load_membership
        @membership = current_inventory.inventory_memberships.find(params[:id])
      end

      # Anything unrecognised falls back to the safer of the two roles.
      def requested_role
        role = params[:role].to_s
        InventoryMembership::ASSIGNABLE_ROLES.include?(role) ? role : InventoryMembership::VIEWER
      end

      def serialize(membership)
        {
          id: membership.id,
          role: membership.role,
          inventory_id: membership.inventory_id,
          user: {
            id: membership.user.id,
            email: membership.user.email,
            name: membership.user.name
          }
        }
      end
    end
  end
end
