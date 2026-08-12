require "test_helper"

class Api::V1::InventoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob = users(:bob)
    @household = inventories(:shared_household)
  end

  test "requires authentication" do
    get api_v1_inventories_url
    assert_response :unauthorized
  end

  test "index lists personal and shared inventories with the caller's role" do
    get api_v1_inventories_url, headers: auth_headers(@bob)
    assert_response :success
    body = JSON.parse(response.body)

    personal = body.find { |i| i["personal"] }
    shared = body.find { |i| i["id"] == @household.id }

    assert_equal "owner", personal["role"]
    assert_equal "editor", shared["role"], "Bob is an editor on Alice's Household"
    assert_equal @alice.email, shared["owner"]["email"]
  end

  test "index puts the personal inventory first" do
    get api_v1_inventories_url, headers: auth_headers(@alice)
    assert_response :success
    assert JSON.parse(response.body).first["personal"]
  end

  test "index does not include inventories the user is not a member of" do
    stranger_inventory = Inventory.create!(name: "Stranger's", owner: users(:unverified))
    get api_v1_inventories_url, headers: auth_headers(@bob)
    ids = JSON.parse(response.body).map { |i| i["id"] }
    assert_not_includes ids, stranger_inventory.id
  end

  test "create makes a shared inventory owned by the caller" do
    assert_difference("Inventory.count", 1) do
      post api_v1_inventories_url, params: { name: "Garage" }, headers: auth_headers(@bob)
    end
    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "Garage", body["name"]
    assert_equal "owner", body["role"]
    assert_not body["personal"]
    assert_equal 1, body["member_count"], "The creator is a member of their own inventory"
  end

  test "create rejects a blank name" do
    post api_v1_inventories_url, params: { name: "" }, headers: auth_headers(@bob)
    assert_response :unprocessable_entity
  end

  test "update renames an inventory the caller owns" do
    patch api_v1_inventory_url(@household), params: { name: "The House" },
                                            headers: auth_headers(@alice)
    assert_response :success
    assert_equal "The House", @household.reload.name
  end

  test "update is forbidden for a non-owner member" do
    patch api_v1_inventory_url(@household), params: { name: "Bob's House" },
                                            headers: auth_headers(@bob)
    assert_response :forbidden
    assert_equal "Household", @household.reload.name
  end

  test "update 404s for an inventory the caller cannot see" do
    stranger_inventory = Inventory.create!(name: "Stranger's", owner: users(:unverified))
    patch api_v1_inventory_url(stranger_inventory), params: { name: "Mine now" },
                                                    headers: auth_headers(@bob)
    assert_response :not_found
  end

  test "destroy removes a shared inventory and its items" do
    create_item(@alice, name: "Shared thing", inventory: @household)
    assert_difference(["Inventory.count", "Item.count"], -1) do
      delete api_v1_inventory_url(@household), headers: auth_headers(@alice)
    end
    assert_response :no_content
  end

  test "destroy refuses to delete a personal inventory" do
    personal = @alice.personal_inventory
    delete api_v1_inventory_url(personal), headers: auth_headers(@alice)
    assert_response :unprocessable_entity
    assert Inventory.exists?(personal.id)
  end
end
