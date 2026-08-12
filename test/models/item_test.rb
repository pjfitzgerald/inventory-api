require "test_helper"

class ItemTest < ActiveSupport::TestCase
  setup do
    @user = users(:alice)
    @inventory = @user.personal_inventory
  end

  test "should not save item without name" do
    item = @inventory.items.build(category: "book", user: @user)
    assert_not item.save, "Saved the item without a name"
  end

  test "should save valid item" do
    item = @inventory.items.build(name: "Test Item", category: "electronics", user: @user)
    assert item.save, "Could not save a valid item"
  end

  test "requires an inventory" do
    item = Item.new(name: "Homeless Item", user: @user)
    assert_not item.save, "Saved an item that is not in any inventory"
  end

  test "does not require a creator" do
    item = @inventory.items.build(name: "Authorless Item")
    assert item.save, "Could not save an item with no creator"
  end

  test "tags getter converts comma-separated string to array" do
    item = create_item(@user, name: "Test", tags: "tag1, tag2, tag3")
    assert_equal ["tag1", "tag2", "tag3"], item.tags
  end

  test "tags setter converts array to comma-separated string" do
    item = @inventory.items.build(name: "Test", user: @user)
    item.tags = ["one", "two", "three"]
    item.save!
    assert_equal "one,two,three", item[:tags]
  end

  test "search scope finds items by name" do
    create_item(@user, name: "Test Keyboard", category: "electronics")
    create_item(@user, name: "Test Mouse", category: "electronics")

    results = Item.search("Keyboard")
    assert_equal 1, results.count
    assert_equal "Test Keyboard", results.first.name
  end

  test "search scope is case insensitive" do
    create_item(@user, name: "Test KEYBOARD", category: "electronics")

    assert_equal 1, Item.search("keyboard").count
  end

  test "search scope finds items by category" do
    create_item(@user, name: "Unique Category Item", category: "photography")

    results = Item.search("photography")
    assert_equal 1, results.count
    assert_equal "photography", results.first.category
  end

  test "status defaults to Keep" do
    item = create_item(@user, name: "New Item")
    assert_equal "Keep", item.status
  end
end
