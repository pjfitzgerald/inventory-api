module Api
  module V1
    class ItemsController < ApplicationController
      # Reads are open to every member of the inventory; writes need at least
      # editor. Which inventory is in play comes from `?inventory_id=`, and
      # defaults to the user's personal one so existing clients keep working.
      before_action :require_edit_access!, only: %i[create]
      before_action :load_item, only: %i[show update destroy]
      before_action :require_item_edit_access!, only: %i[update destroy]

      def index
        @items = if params[:query].present?
          current_inventory.items.search(params[:query])
        else
          current_inventory.items
        end

        render json: @items
      end

      def show
        render json: @item
      end

      def create
        @item = current_inventory.items.new(item_params.merge(user: current_user))
        if @item.save
          render json: @item, status: :created
        else
          render json: @item.errors, status: :unprocessable_entity
        end
      end

      def update
        if @item.update(item_params)
          render json: @item
        else
          render json: @item.errors, status: :unprocessable_entity
        end
      end

      def destroy
        @item.destroy
        head :no_content
      end

      private

      # An item is addressed by id alone, so find it across everything the user
      # can reach rather than only the inventory named in the request.
      def load_item
        @item = Item.where(inventory: accessible_inventories).find(params[:id])
      end

      # Editing is gated on the role in the item's own inventory.
      def require_item_edit_access!
        return if @item.inventory.membership_for(current_user)&.can_edit_items?

        render json: { error: 'You have view-only access to this inventory' },
               status: :forbidden
      end

      def item_params
        params.require(:item).permit(
          :name,
          :quantity,
          :category,
          :current_location,
          :weight,
          :owner,
          :intended_location,
          :notes,
          :location_notes,
          :status,
          :created_at,
          :updated_at,
          tags: [],
          custom_fields: {}
        )
      end
    end
  end
end
