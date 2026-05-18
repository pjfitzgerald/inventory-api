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

  test "start_password_reset! issues a token and timestamp" do
    user = users(:alice)
    user.start_password_reset!
    assert user.password_reset_token.present?
    assert user.password_reset_sent_at.present?
    assert user.password_reset_valid?
  end

  test "password_reset_valid? is false without a reset request" do
    assert_not users(:alice).password_reset_valid?
  end

  test "password_reset_valid? is false once the TTL has lapsed" do
    user = users(:alice)
    user.start_password_reset!
    user.update!(password_reset_sent_at: (User::PASSWORD_RESET_TTL + 1.minute).ago)
    assert_not user.password_reset_valid?
  end

  test "reset_password! sets the password, verifies the email, and clears tokens" do
    user = users(:unverified)
    user.start_password_reset!
    assert user.reset_password!("brandnewpass")
    assert user.authenticate("brandnewpass")
    assert user.email_verified?
    assert_nil user.password_reset_token
    assert_nil user.email_verification_token
  end

  test "reset_password! returns false for an invalid password" do
    assert_not users(:alice).reset_password!("short")
  end
end
