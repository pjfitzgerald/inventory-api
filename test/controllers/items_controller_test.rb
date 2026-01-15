require "test_helper"

class Api::V1::ItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @item = Item.create!(name: "Test Item", category: "electronics", status: "Keep")
  end

  test "index returns all items" do
    get api_v1_items_url
    assert_response :success
    items = JSON.parse(response.body)
    assert items.is_a?(Array)
  end

  test "index with query returns filtered items" do
    Item.create!(name: "Keyboard", category: "electronics")
    get api_v1_items_url, params: { query: "Keyboard" }
    assert_response :success
    items = JSON.parse(response.body)
    assert items.any? { |i| i["name"] == "Keyboard" }
  end

  test "show returns a single item" do
    get api_v1_item_url(@item)
    assert_response :success
    item = JSON.parse(response.body)
    assert_equal @item.name, item["name"]
  end

  test "create adds a new item" do
    assert_difference("Item.count", 1) do
      post api_v1_items_url, params: { item: { name: "New Item", category: "books" } }
    end
    assert_response :created
    item = JSON.parse(response.body)
    assert_equal "New Item", item["name"]
  end

  test "create fails without name" do
    assert_no_difference("Item.count") do
      post api_v1_items_url, params: { item: { category: "books" } }
    end
    assert_response :unprocessable_entity
  end

  test "update modifies an existing item" do
    patch api_v1_item_url(@item), params: { item: { name: "Updated Item" } }
    assert_response :success
    @item.reload
    assert_equal "Updated Item", @item.name
  end

  test "destroy removes an item" do
    assert_difference("Item.count", -1) do
      delete api_v1_item_url(@item)
    end
    assert_response :no_content
  end
end
