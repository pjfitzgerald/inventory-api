require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "is valid with email and password" do
    user = User.new(email: "valid@example.com", password: "password123")
    assert user.valid?
  end

  test "requires an email" do
    user = User.new(password: "password123")
    assert_not user.valid?
  end

  test "rejects a malformed email" do
    user = User.new(email: "not-an-email", password: "password123")
    assert_not user.valid?
  end

  test "requires a unique email, case-insensitively" do
    user = User.new(email: users(:alice).email.upcase, password: "password123")
    assert_not user.valid?
  end

  test "normalizes email to lowercase and strips whitespace" do
    user = User.create!(email: "  Mixed@Example.COM ", password: "password123")
    assert_equal "mixed@example.com", user.email
  end

  test "requires a password of at least 8 characters" do
    user = User.new(email: "short@example.com", password: "abc")
    assert_not user.valid?
  end

  test "authenticates with the correct password" do
    user = User.create!(email: "auth@example.com", password: "password123")
    assert user.authenticate("password123")
    assert_not user.authenticate("wrong")
  end

  test "email_verified? reflects email_verified_at" do
    assert users(:alice).email_verified?
    assert_not users(:unverified).email_verified?
  end

  test "verify_email! sets the timestamp and clears the token" do
    user = users(:unverified)
    user.verify_email!
    assert user.email_verified?
    assert_nil user.email_verification_token
  end

  test "destroying a user destroys their items" do
    user = User.create!(email: "owner@example.test", password: "password123")
    user.items.create!(name: "Doomed item")
    assert_difference("Item.count", -1) { user.destroy }
  end
end
