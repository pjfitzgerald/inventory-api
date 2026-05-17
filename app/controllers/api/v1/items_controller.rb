module Api
  module V1
    class ItemsController < ApplicationController
      def index
        @items = if params[:query].present?
          current_user.items.search(params[:query])
        else
          current_user.items
        end

        render json: @items
      end

      def show
        @item = current_user.items.find(params[:id])
        render json: @item
      end

      def create
        @item = current_user.items.new(item_params)
        if @item.save
          render json: @item, status: :created
        else
          render json: @item.errors, status: :unprocessable_entity
        end
      end

      def update
        @item = current_user.items.find(params[:id])
        if @item.update(item_params)
          render json: @item
        else
          render json: @item.errors, status: :unprocessable_entity
        end
      end

      def destroy
        @item = current_user.items.find(params[:id])
        @item.destroy
        head :no_content
      end

      private
      
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