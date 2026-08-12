require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "is valid with email and password" do
    user = User.new(email: "valid@example.com", password: "correcthorsebattery")
    assert user.valid?
  end

  test "requires an email" do
    user = User.new(password: "correcthorsebattery")
    assert_not user.valid?
  end

  test "rejects a malformed email" do
    user = User.new(email: "not-an-email", password: "correcthorsebattery")
    assert_not user.valid?
  end

  test "requires a unique email, case-insensitively" do
    user = User.new(email: users(:alice).email.upcase, password: "correcthorsebattery")
    assert_not user.valid?
  end

  test "normalizes email to lowercase and strips whitespace" do
    user = User.create!(email: "  Mixed@Example.COM ", password: "correcthorsebattery")
    assert_equal "mixed@example.com", user.email
  end

  test "requires a password of at least the minimum length" do
    user = User.new(email: "short@example.com", password: "a" * (User::PASSWORD_MIN_LENGTH - 1))
    assert_not user.valid?
    assert user.errors.of_kind?(:password, :too_short)
  end

  # bcrypt silently ignores anything past 72 bytes, so a longer password is
  # rejected rather than half-honoured.
  test "rejects a password longer than bcrypt's 72-byte limit" do
    user = User.new(email: "long@example.com", password: "a" * (User::PASSWORD_MAX_LENGTH + 1))
    assert_not user.valid?
    assert user.errors.of_kind?(:password, :too_long)
  end

  test "rejects a common password, including dressed-up variants" do
    %w[password!! Password123 letmein!!! monkey2024 qwerty99!! 1234567890].each do |candidate|
      user = User.new(email: "common@example.com", password: candidate)
      assert_not user.valid?, "expected #{candidate.inspect} to be rejected"
    end
  end

  test "rejects a password containing the email local part" do
    user = User.new(email: "jellyfish@example.com", password: "myJellyFishPass")
    assert_not user.valid?
    assert_includes user.errors[:password], 'must not contain your email address'
  end

  test "accepts a long unremarkable password" do
    user = User.new(email: "fine@example.com", password: "tangerine-shelf-lamp")
    assert user.valid?, user.errors.full_messages.to_sentence
  end

  test "authenticates with the correct password" do
    user = User.create!(email: "auth@example.com", password: "correcthorsebattery")
    assert user.authenticate("correcthorsebattery")
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
    user = User.create!(email: "owner@example.test", password: "correcthorsebattery")
    create_item(user, name: "Doomed item")
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
