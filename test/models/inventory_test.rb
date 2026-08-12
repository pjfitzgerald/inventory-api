require "test_helper"

class InventoryTest < ActiveSupport::TestCase
  test "a new account gets a personal inventory with an owner membership" do
    user = User.create!(email: "fresh@example.com", password: "correcthorsebattery")
    inventory = user.personal_inventory

    assert inventory.personal?
    assert_equal "Personal", inventory.name
    assert_equal user, inventory.owner
    assert_equal "owner", inventory.role_for(user)
  end

  test "personal_inventory creates one for accounts that skipped the callback" do
    # Fixtures insert rows directly, so this stands in for any user created
    # outside the model layer (rake tasks, migrations).
    user = users(:alice)
    user.inventories.personal.destroy_all
    assert_difference("Inventory.count", 1) { user.personal_inventory }
  end

  test "a user cannot have two personal inventories" do
    duplicate = Inventory.new(name: "Personal", owner: users(:alice), personal: true)
    assert_not duplicate.valid?
    assert_includes duplicate.errors.full_messages.join, "already exists"
  end

  test "creating an inventory makes the owner a member" do
    inventory = Inventory.create!(name: "Garage", owner: users(:bob))
    assert_equal [users(:bob)], inventory.members.to_a
    assert inventory.membership_for(users(:bob)).can_manage?
  end

  test "a name is required and capped" do
    assert_not Inventory.new(name: "", owner: users(:bob)).valid?
    assert_not Inventory.new(name: "x" * 61, owner: users(:bob)).valid?
  end

  test "roles decide what a member may do" do
    inventory = inventories(:shared_household)
    editor = inventory.membership_for(users(:bob))

    assert editor.can_edit_items?
    assert_not editor.can_manage?

    editor.update!(role: "viewer")
    assert_not editor.can_edit_items?
  end

  test "an unknown role is rejected" do
    membership = InventoryMembership.new(inventory: inventories(:shared_household),
                                         user: users(:unverified), role: "admin")
    assert_not membership.valid?
  end

  test "destroying an inventory destroys its items and memberships" do
    inventory = inventories(:shared_household)
    create_item(users(:alice), name: "Doomed", inventory: inventory)

    assert_difference("Item.count", -1) do
      assert_difference("InventoryMembership.count", -2) { inventory.destroy }
    end
  end

  test "deleting an account leaves items it added to a shared inventory" do
    inventory = inventories(:shared_household)
    item = create_item(users(:bob), name: "Bob's contribution", inventory: inventory)

    assert_no_difference("Item.count") { users(:bob).destroy }
    assert_nil item.reload.user_id, "The item outlives its author, without one"
    assert_equal inventory, item.inventory
  end
end
