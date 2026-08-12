require "test_helper"

class Api::V1::ItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:alice)
    @other = users(:bob)
    # Alice owns Household; Bob is an editor on it.
    @household = inventories(:shared_household)
    @item = create_item(@user, name: "Test Item", category: "electronics", status: "Keep")
  end

  test "requires authentication" do
    get api_v1_items_url
    assert_response :unauthorized
  end

  test "index returns only the current user's items" do
    other_item = create_item(@other, name: "Bob's Item")
    get api_v1_items_url, headers: auth_headers(@user)
    assert_response :success
    ids = JSON.parse(response.body).map { |i| i["id"] }
    assert_includes ids, @item.id
    assert_not_includes ids, other_item.id
  end

  test "index with query filters the current user's items" do
    create_item(@user, name: "Keyboard", category: "electronics")
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
    other_item = create_item(@other, name: "Bob's Item")
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

  # The CSV / JSON backup import replays the exported created_at and
  # updated_at rather than letting them reset to import time, so a restored
  # inventory keeps its real history. Rails only auto-stamps timestamps that
  # aren't already set, so passing them through must survive a create.
  test "create preserves supplied created_at and updated_at" do
    created = Time.utc(2021, 3, 4, 5, 6, 7)
    updated = Time.utc(2022, 8, 9, 10, 11, 12)

    post api_v1_items_url,
         params: { item: { name: "Imported Item",
                           created_at: created.iso8601,
                           updated_at: updated.iso8601 } },
         headers: auth_headers(@user)

    assert_response :created
    item = Item.find(JSON.parse(response.body)["id"])
    assert_equal created, item.created_at
    assert_equal updated, item.updated_at
  end

  # Every other column the CSV exporter writes must be accepted back on
  # import — a field the controller doesn't permit would be silently dropped
  # and the round trip would lose data.
  test "create accepts every field the CSV export writes" do
    attrs = {
      name: "Full Item",
      quantity: 3,
      category: "electronics",
      tags: %w[one two],
      current_location: "Shed",
      weight: "1.5",
      owner: "PJF",
      intended_location: "Garage",
      notes: "some notes",
      location_notes: "top shelf",
      status: "Sell",
      custom_fields: { "serial_number" => "ABC123" }
    }

    post api_v1_items_url, params: { item: attrs }, headers: auth_headers(@user)

    assert_response :created
    item = Item.find(JSON.parse(response.body)["id"])
    assert_equal "Full Item", item.name
    assert_equal 3, item.quantity
    assert_equal "electronics", item.category
    assert_equal %w[one two], item.tags
    assert_equal "Shed", item.current_location
    assert_equal 1.5, item.weight
    assert_equal "PJF", item.owner
    assert_equal "Garage", item.intended_location
    assert_equal "some notes", item.notes
    assert_equal "top shelf", item.location_notes
    assert_equal "Sell", item.status
    assert_equal({ "serial_number" => "ABC123" }, item.custom_fields)
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
    other_item = create_item(@other, name: "Bob's Item")
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
    other_item = create_item(@other, name: "Bob's Item")
    assert_no_difference("Item.count") do
      delete api_v1_item_url(other_item), headers: auth_headers(@user)
    end
    assert_response :not_found
  end

  # --- shared inventories ---------------------------------------------------

  test "index defaults to the caller's personal inventory" do
    shared_item = create_item(@user, name: "Shared thing", inventory: @household)
    get api_v1_items_url, headers: auth_headers(@user)
    assert_response :success
    ids = JSON.parse(response.body).map { |i| i["id"] }
    assert_includes ids, @item.id
    assert_not_includes ids, shared_item.id
  end

  test "index returns a shared inventory's items when asked for it" do
    shared_item = create_item(@user, name: "Shared thing", inventory: @household)
    get api_v1_items_url, params: { inventory_id: @household.id }, headers: auth_headers(@other)
    assert_response :success
    ids = JSON.parse(response.body).map { |i| i["id"] }
    assert_equal [shared_item.id], ids
  end

  test "index 404s for an inventory the caller is not a member of" do
    stranger_inventory = Inventory.create!(name: "Stranger's", owner: users(:unverified))
    get api_v1_items_url, params: { inventory_id: stranger_inventory.id },
                          headers: auth_headers(@user)
    assert_response :not_found
  end

  test "create puts the item in the requested shared inventory" do
    post api_v1_items_url,
         params: { inventory_id: @household.id, item: { name: "Lawnmower" } },
         headers: auth_headers(@other)
    assert_response :created
    item = Item.find(JSON.parse(response.body)["id"])
    assert_equal @household, item.inventory
    assert_equal @other, item.user, "The item records who added it"
  end

  test "show returns an item from a shared inventory" do
    shared_item = create_item(@user, name: "Shared thing", inventory: @household)
    get api_v1_item_url(shared_item), headers: auth_headers(@other)
    assert_response :success
  end

  test "a member can update another member's item" do
    shared_item = create_item(@user, name: "Shared thing", inventory: @household)
    patch api_v1_item_url(shared_item), params: { item: { name: "Renamed" } },
                                        headers: auth_headers(@other)
    assert_response :success
    assert_equal "Renamed", shared_item.reload.name
  end

  test "a viewer can read but not create" do
    demote_bob_to_viewer
    get api_v1_items_url, params: { inventory_id: @household.id }, headers: auth_headers(@other)
    assert_response :success

    assert_no_difference("Item.count") do
      post api_v1_items_url,
           params: { inventory_id: @household.id, item: { name: "Nope" } },
           headers: auth_headers(@other)
    end
    assert_response :forbidden
  end

  test "a viewer cannot update or delete an item" do
    shared_item = create_item(@user, name: "Shared thing", inventory: @household)
    demote_bob_to_viewer

    patch api_v1_item_url(shared_item), params: { item: { name: "Nope" } },
                                        headers: auth_headers(@other)
    assert_response :forbidden
    assert_equal "Shared thing", shared_item.reload.name

    assert_no_difference("Item.count") do
      delete api_v1_item_url(shared_item), headers: auth_headers(@other)
    end
    assert_response :forbidden
  end

  test "a viewer role on one inventory does not restrict their own" do
    demote_bob_to_viewer
    post api_v1_items_url, params: { item: { name: "Bob's own thing" } },
                           headers: auth_headers(@other)
    assert_response :created
  end

  private

  def demote_bob_to_viewer
    inventory_memberships(:household_editor).update!(role: "viewer")
  end
end
