require "test_helper"

class ItemTest < ActiveSupport::TestCase
  test "should not save item without name" do
    item = Item.new(category: "book")
    assert_not item.save, "Saved the item without a name"
  end

  test "should save valid item" do
    item = Item.new(name: "Test Item", category: "electronics")
    assert item.save, "Could not save a valid item"
  end

  test "tags getter converts comma-separated string to array" do
    item = Item.new(name: "Test", tags: "tag1, tag2, tag3")
    item.save
    assert_equal ["tag1", "tag2", "tag3"], item.tags
  end

  test "tags setter converts array to comma-separated string" do
    item = Item.new(name: "Test")
    item.tags = ["one", "two", "three"]
    item.save
    assert_equal "one,two,three", item[:tags]
  end

  test "search scope finds items by name" do
    Item.create!(name: "Test Keyboard", category: "electronics")
    Item.create!(name: "Test Mouse", category: "electronics")

    results = Item.search("Keyboard")
    assert_equal 1, results.count
    assert_equal "Test Keyboard", results.first.name
  end

  test "search scope is case insensitive" do
    Item.create!(name: "Test KEYBOARD", category: "electronics")

    results = Item.search("keyboard")
    assert_equal 1, results.count
  end

  test "search scope finds items by category" do
    Item.create!(name: "Unique Category Item", category: "photography")
    Item.create!(name: "Other Item", category: "electronics")

    results = Item.search("photography")
    assert_equal 1, results.count
    assert_equal "photography", results.first.category
  end

  test "status defaults to Keep" do
    item = Item.create!(name: "New Item")
    assert_equal "Keep", item.status
  end
end
