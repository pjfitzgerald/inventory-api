require "test_helper"

class ItemTest < ActiveSupport::TestCase
  setup do
    @user = users(:alice)
  end

  test "should not save item without name" do
    item = @user.items.build(category: "book")
    assert_not item.save, "Saved the item without a name"
  end

  test "should save valid item" do
    item = @user.items.build(name: "Test Item", category: "electronics")
    assert item.save, "Could not save a valid item"
  end

  test "requires a user" do
    item = Item.new(name: "Ownerless Item")
    assert_not item.save, "Saved an item with no user"
  end

  test "tags getter converts comma-separated string to array" do
    item = @user.items.create!(name: "Test", tags: "tag1, tag2, tag3")
    assert_equal ["tag1", "tag2", "tag3"], item.tags
  end

  test "tags setter converts array to comma-separated string" do
    item = @user.items.build(name: "Test")
    item.tags = ["one", "two", "three"]
    item.save!
    assert_equal "one,two,three", item[:tags]
  end

  test "search scope finds items by name" do
    @user.items.create!(name: "Test Keyboard", category: "electronics")
    @user.items.create!(name: "Test Mouse", category: "electronics")

    results = Item.search("Keyboard")
    assert_equal 1, results.count
    assert_equal "Test Keyboard", results.first.name
  end

  test "search scope is case insensitive" do
    @user.items.create!(name: "Test KEYBOARD", category: "electronics")

    assert_equal 1, Item.search("keyboard").count
  end

  test "search scope finds items by category" do
    @user.items.create!(name: "Unique Category Item", category: "photography")

    results = Item.search("photography")
    assert_equal 1, results.count
    assert_equal "photography", results.first.category
  end

  test "status defaults to Keep" do
    item = @user.items.create!(name: "New Item")
    assert_equal "Keep", item.status
  end
end
