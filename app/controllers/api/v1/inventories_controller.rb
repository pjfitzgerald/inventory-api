module Api
  module V1
    class InventoriesController < ApplicationController
      before_action :load_inventory, only: %i[update destroy]

      # Everything the user can reach, personal first, then oldest shared.
      def index
        inventories = accessible_inventories
                      .includes(:owner)
                      .order(personal: :desc, created_at: :asc)

        render json: inventories.map { |inventory| serialize(inventory) }
      end

      def create
        inventory = Inventory.new(name: params.dig(:inventory, :name) || params[:name],
                                  owner: current_user,
                                  personal: false)

        if inventory.save
          render json: serialize(inventory), status: :created
        else
          render json: { errors: inventory.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      def update
        if @inventory.update(name: params.dig(:inventory, :name) || params[:name])
          render json: serialize(@inventory)
        else
          render json: { errors: @inventory.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      def destroy
        if @inventory.personal?
          return render json: { error: 'Your personal inventory cannot be deleted' },
                        status: :unprocessable_entity
        end

        @inventory.destroy
        head :no_content
      end

      private

      # Renaming and deleting are owner-only. Loading through
      # `accessible_inventories` keeps a stranger's id a 404.
      def load_inventory
        @inventory = accessible_inventories.find(params[:id])
        return if @inventory.membership_for(current_user)&.can_manage?

        render json: { error: 'Only the owner can manage this inventory' },
               status: :forbidden
      end

      def serialize(inventory)
        {
          id: inventory.id,
          name: inventory.name,
          personal: inventory.personal,
          role: inventory.role_for(current_user),
          item_count: inventory.items.count,
          member_count: inventory.inventory_memberships.count,
          owner: {
            id: inventory.owner.id,
            email: inventory.owner.email,
            name: inventory.owner.name
          }
        }
      end
    end
  end
end
