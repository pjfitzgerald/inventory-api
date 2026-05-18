require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "verify_email with a valid token verifies the user" do
    user = users(:unverified)
    get verify_email_url(token: user.email_verification_token)
    assert_response :success
    assert_match(/verified/i, response.body)
    assert user.reload.email_verified?
  end

  test "verify_email with an invalid token shows an error page" do
    get verify_email_url(token: "bogus-token")
    assert_response :unprocessable_entity
    assert_match(/invalid/i, response.body)
  end

  test "reset_password form renders for a valid token" do
    user = users(:alice)
    user.start_password_reset!
    get reset_password_url(token: user.password_reset_token)
    assert_response :success
    assert_match user.password_reset_token, response.body
    assert_match(/type="password"/, response.body)
  end

  test "reset_password form rejects an invalid token" do
    get reset_password_url(token: "bogus-token")
    assert_response :unprocessable_entity
    assert_match(/invalid/i, response.body)
  end

  test "posting reset_password updates the password" do
    user = users(:alice)
    user.start_password_reset!
    post reset_password_url, params: { token: user.password_reset_token, password: "newpassword1" }
    assert_response :success
    assert_match(/updated/i, response.body)
    assert user.reload.authenticate("newpassword1")
  end

  test "posting reset_password with an expired token shows an error" do
    user = users(:alice)
    user.start_password_reset!
    user.update!(password_reset_sent_at: 3.hours.ago)
    post reset_password_url, params: { token: user.password_reset_token, password: "newpassword1" }
    assert_response :unprocessable_entity
    assert_match(/invalid|expired/i, response.body)
  end

  test "posting reset_password with a short password re-renders the form with an error" do
    user = users(:alice)
    user.start_password_reset!
    post reset_password_url, params: { token: user.password_reset_token, password: "abc" }
    assert_response :unprocessable_entity
    assert_match(/too short/i, response.body)
  end
end
