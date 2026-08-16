module Api
  module V1
    class ItemsController < ApplicationController
      # Reads are open to every member of the inventory; writes need at least
      # editor. Which inventory is in play comes from `?inventory_id=`, and
      # defaults to the user's personal one so existing clients keep working.
      before_action :require_edit_access!, only: %i[create trash purge]
      before_action :load_item, only: %i[show update destroy restore]
      before_action :require_item_edit_access!, only: %i[update destroy restore]

      def index
        @items = if params[:query].present?
          current_inventory.items.kept.search(params[:query])
        else
          current_inventory.items.kept
        end

        render json: @items
      end

      # The recycle bin for this inventory. Listing it is also when expired
      # items get dropped, so the bin the user sees is the bin that exists.
      def trash
        Item.purge_expired!(current_inventory.items)

        render json: {
          items: current_inventory.items.discarded.order(deleted_at: :desc),
          retention_days: Item::TRASH_RETENTION_DAYS
        }
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

      # Soft delete by default. `?permanent=true` skips the bin — used by the
      # replace-mode CSV import, which clears hundreds of items at once and
      # would otherwise bury whatever was already in there.
      def destroy
        if ActiveModel::Type::Boolean.new.cast(params[:permanent])
          @item.destroy
        else
          @item.discard!
        end
        head :no_content
      end

      # Undo. Restoring an item that was never deleted is a no-op rather than
      # an error, so a double-tapped undo is harmless.
      def restore
        @item.restore!
        render json: @item
      end

      # Empty the bin for this inventory.
      def purge
        count = current_inventory.items.discarded.delete_all
        render json: { purged: count }
      end

      private

      # An item is addressed by id alone, so find it across everything the user
      # can reach rather than only the inventory named in the request. Deleted
      # items are included: restore and permanent-delete both need to reach
      # them, and `show` on a binned item is harmless.
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
          :sublocation,
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
