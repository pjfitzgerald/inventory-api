module Api
  module V1
    class ItemsController < ApplicationController
      def index
        @items = if params[:query].present?
          Item.search(params[:query])
        else
          Item.all
        end
        
        render json: @items
      end
      
      def show
        @item = Item.find(params[:id])
        render json: @item
      end
      
      def create
        @item = Item.new(item_params)
        if @item.save
          render json: @item, status: :created
        else
          render json: @item.errors, status: :unprocessable_entity
        end
      end
      
      def update
        @item = Item.find(params[:id])
        if @item.update(item_params)
          render json: @item
        else
          render json: @item.errors, status: :unprocessable_entity
        end
      end
      
      def destroy
        @item = Item.find(params[:id])
        @item.destroy
        head :no_content
      end
      
      private
      
      def item_params
        params.require(:item).permit(
          :name,
          :quantity,
          :category,
          :tags,
          :current_location,
          :weight,
          :owner,
          :intended_location,
          :notes,
          :location_notes,
          :potential_discard_sell
        )
      end
    end
  end
end