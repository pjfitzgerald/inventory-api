require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "verification_email is addressed to the user and carries the verify link" do
    user = users(:unverified)
    email = UserMailer.verification_email(user)
    link = "/verify_email?token=#{user.email_verification_token}"

    assert_equal [user.email], email.to
    assert_match(/verify/i, email.subject)
    assert_match link, email.text_part.body.decoded
    assert_match link, email.html_part.body.decoded
  end

  test "password_reset_email is addressed to the user and carries the reset link" do
    user = users(:alice)
    user.start_password_reset!
    email = UserMailer.password_reset_email(user)
    link = "/reset_password?token=#{user.password_reset_token}"

    assert_equal [user.email], email.to
    assert_match(/reset/i, email.subject)
    assert_match link, email.text_part.body.decoded
    assert_match link, email.html_part.body.decoded
  end
end
