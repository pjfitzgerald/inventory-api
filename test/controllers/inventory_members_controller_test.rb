require "test_helper"

class Api::V1::InventoryMembersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob = users(:bob)
    @household = inventories(:shared_household)
    @bobs_membership = inventory_memberships(:household_editor)
  end

  test "index lists the members of a shared inventory" do
    get api_v1_inventory_members_url(@household), headers: auth_headers(@bob)
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal %w[owner editor], body.map { |m| m["role"] }
    assert_equal [@alice.email, @bob.email], body.map { |m| m.dig("user", "email") }
  end

  test "index 404s for a non-member" do
    get api_v1_inventory_members_url(@household), headers: auth_headers(users(:unverified))
    assert_response :not_found
  end

  test "create adds an existing verified account as an editor" do
    carol = User.create!(email: "carol@example.com", password: "correcthorsebattery",
                         email_verified_at: Time.current)
    assert_difference("InventoryMembership.count", 1) do
      post api_v1_inventory_members_url(@household),
           params: { email: "carol@example.com", role: "editor" },
           headers: auth_headers(@alice)
    end
    assert_response :created
    assert_equal "editor", JSON.parse(response.body)["role"]
    assert_includes @household.reload.members, carol
  end

  test "create matches the email case-insensitively" do
    User.create!(email: "carol@example.com", password: "correcthorsebattery",
                 email_verified_at: Time.current)
    post api_v1_inventory_members_url(@household),
         params: { email: "  CAROL@Example.com " }, headers: auth_headers(@alice)
    assert_response :created
  end

  test "create defaults to the viewer role when none is given" do
    User.create!(email: "carol@example.com", password: "correcthorsebattery",
                 email_verified_at: Time.current)
    post api_v1_inventory_members_url(@household),
         params: { email: "carol@example.com" }, headers: auth_headers(@alice)
    assert_response :created
    assert_equal "viewer", JSON.parse(response.body)["role"]
  end

  test "create refuses to grant ownership" do
    User.create!(email: "carol@example.com", password: "correcthorsebattery",
                 email_verified_at: Time.current)
    post api_v1_inventory_members_url(@household),
         params: { email: "carol@example.com", role: "owner" }, headers: auth_headers(@alice)
    assert_response :created
    assert_equal "viewer", JSON.parse(response.body)["role"]
  end

  test "create 404s when no account has that email" do
    post api_v1_inventory_members_url(@household),
         params: { email: "nobody@example.com" }, headers: auth_headers(@alice)
    assert_response :not_found
    assert_match(/sign up/i, JSON.parse(response.body)["error"])
  end

  test "create rejects an unverified account" do
    post api_v1_inventory_members_url(@household),
         params: { email: users(:unverified).email }, headers: auth_headers(@alice)
    assert_response :unprocessable_entity
  end

  test "create rejects a duplicate member" do
    post api_v1_inventory_members_url(@household),
         params: { email: @bob.email }, headers: auth_headers(@alice)
    assert_response :unprocessable_entity
  end

  test "create is forbidden for a non-owner member" do
    User.create!(email: "carol@example.com", password: "correcthorsebattery",
                 email_verified_at: Time.current)
    post api_v1_inventory_members_url(@household),
         params: { email: "carol@example.com" }, headers: auth_headers(@bob)
    assert_response :forbidden
  end

  test "create refuses to share a personal inventory" do
    post api_v1_inventory_members_url(@alice.personal_inventory),
         params: { email: @bob.email }, headers: auth_headers(@alice)
    assert_response :unprocessable_entity
  end

  test "update changes a member's role" do
    patch api_v1_inventory_member_url(@household, @bobs_membership),
          params: { role: "viewer" }, headers: auth_headers(@alice)
    assert_response :success
    assert_equal "viewer", @bobs_membership.reload.role
  end

  test "update cannot change the owner's role" do
    owner_membership = inventory_memberships(:household_owner)
    patch api_v1_inventory_member_url(@household, owner_membership),
          params: { role: "viewer" }, headers: auth_headers(@alice)
    assert_response :unprocessable_entity
    assert_equal "owner", owner_membership.reload.role
  end

  test "update is forbidden for a non-owner member" do
    patch api_v1_inventory_member_url(@household, @bobs_membership),
          params: { role: "viewer" }, headers: auth_headers(@bob)
    assert_response :forbidden
  end

  test "destroy removes a member" do
    assert_difference("InventoryMembership.count", -1) do
      delete api_v1_inventory_member_url(@household, @bobs_membership),
             headers: auth_headers(@alice)
    end
    assert_response :no_content
  end

  test "a member can remove themselves" do
    assert_difference("InventoryMembership.count", -1) do
      delete api_v1_inventory_member_url(@household, @bobs_membership),
             headers: auth_headers(@bob)
    end
    assert_response :no_content
  end

  test "the owner cannot be removed" do
    delete api_v1_inventory_member_url(@household, inventory_memberships(:household_owner)),
           headers: auth_headers(@alice)
    assert_response :unprocessable_entity
  end

  test "removing a member leaves the items in place" do
    create_item(@bob, name: "Bob's contribution", inventory: @household)
    assert_no_difference("Item.count") do
      delete api_v1_inventory_member_url(@household, @bobs_membership),
             headers: auth_headers(@alice)
    end
  end
end
