require "test_helper"

class Api::V1::ItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:alice)
    @other = users(:bob)
    @item = @user.items.create!(name: "Test Item", category: "electronics", status: "Keep")
  end

  test "requires authentication" do
    get api_v1_items_url
    assert_response :unauthorized
  end

  test "index returns only the current user's items" do
    other_item = @other.items.create!(name: "Bob's Item")
    get api_v1_items_url, headers: auth_headers(@user)
    assert_response :success
    ids = JSON.parse(response.body).map { |i| i["id"] }
    assert_includes ids, @item.id
    assert_not_includes ids, other_item.id
  end

  test "index with query filters the current user's items" do
    @user.items.create!(name: "Keyboard", category: "electronics")
    get api_v1_items_url, params: { query: "Keyboard" }, headers: auth_headers(@user)
    assert_response :success
    items = JSON.parse(response.body)
    assert items.any? { |i| i["name"] == "Keyboard" }
  end

  test "show returns the current user's item" do
    get api_v1_item_url(@item), headers: auth_headers(@user)
    assert_response :success
    assert_equal @item.name, JSON.parse(response.body)["name"]
  end

  test "show 404s for another user's item" do
    other_item = @other.items.create!(name: "Bob's Item")
    get api_v1_item_url(other_item), headers: auth_headers(@user)
    assert_response :not_found
  end

  test "create adds an item owned by the current user" do
    assert_difference("Item.count", 1) do
      post api_v1_items_url,
           params: { item: { name: "New Item", category: "books" } },
           headers: auth_headers(@user)
    end
    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "New Item", body["name"]
    assert_equal @user.id, Item.find(body["id"]).user_id
  end

  test "create fails without name" do
    assert_no_difference("Item.count") do
      post api_v1_items_url,
           params: { item: { category: "books" } },
           headers: auth_headers(@user)
    end
    assert_response :unprocessable_entity
  end

  test "update modifies the current user's item" do
    patch api_v1_item_url(@item),
          params: { item: { name: "Updated Item" } },
          headers: auth_headers(@user)
    assert_response :success
    assert_equal "Updated Item", @item.reload.name
  end

  test "update 404s for another user's item" do
    other_item = @other.items.create!(name: "Bob's Item")
    patch api_v1_item_url(other_item),
          params: { item: { name: "Hacked" } },
          headers: auth_headers(@user)
    assert_response :not_found
    assert_equal "Bob's Item", other_item.reload.name
  end

  test "destroy removes the current user's item" do
    assert_difference("Item.count", -1) do
      delete api_v1_item_url(@item), headers: auth_headers(@user)
    end
    assert_response :no_content
  end

  test "destroy 404s for another user's item" do
    other_item = @other.items.create!(name: "Bob's Item")
    assert_no_difference("Item.count") do
      delete api_v1_item_url(other_item), headers: auth_headers(@user)
    end
    assert_response :not_found
  end
end
