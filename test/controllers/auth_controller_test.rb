require "test_helper"

class Api::V1::AuthControllerTest < ActionDispatch::IntegrationTest
  test "signup creates an unverified user and returns a verification token" do
    assert_difference("User.count", 1) do
      post api_v1_auth_signup_url,
           params: { email: "new@example.com", password: "password123", name: "New" },
           as: :json
    end
    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "new@example.com", body["user"]["email"]
    assert_equal false, body["user"]["email_verified"]
    assert body["verification_token"].present?
  end

  test "signup hides verification_token in production without EXPOSE_AUTH_TOKENS" do
    with_rails_env("production") do
      ENV.delete("EXPOSE_AUTH_TOKENS")
      post api_v1_auth_signup_url,
           params: { email: "prod@example.com", password: "password123" },
           as: :json
    end
    assert_response :created
    body = JSON.parse(response.body)
    assert_nil body["verification_token"]
  end

  test "signup exposes verification_token in production when EXPOSE_AUTH_TOKENS=true" do
    with_rails_env("production") do
      ENV["EXPOSE_AUTH_TOKENS"] = "true"
      begin
        post api_v1_auth_signup_url,
             params: { email: "staging@example.com", password: "password123" },
             as: :json
      ensure
        ENV.delete("EXPOSE_AUTH_TOKENS")
      end
    end
    assert_response :created
    body = JSON.parse(response.body)
    assert body["verification_token"].present?
  end

  test "signup rejects a duplicate email" do
    assert_no_difference("User.count") do
      post api_v1_auth_signup_url,
           params: { email: users(:alice).email, password: "password123" },
           as: :json
    end
    assert_response :unprocessable_entity
  end

  test "signup rejects a short password" do
    post api_v1_auth_signup_url,
         params: { email: "short@example.com", password: "abc" },
         as: :json
    assert_response :unprocessable_entity
  end

  test "signup rejects a malformed email" do
    post api_v1_auth_signup_url,
         params: { email: "not-an-email", password: "password123" },
         as: :json
    assert_response :unprocessable_entity
  end

  test "login is forbidden until the email is verified" do
    post api_v1_auth_login_url,
         params: { email: users(:unverified).email, password: "password123" },
         as: :json
    assert_response :forbidden
  end

  test "login rejects a wrong password" do
    post api_v1_auth_login_url,
         params: { email: users(:alice).email, password: "wrong" },
         as: :json
    assert_response :unauthorized
  end

  test "login rejects an unknown email" do
    post api_v1_auth_login_url,
         params: { email: "nobody@example.com", password: "password123" },
         as: :json
    assert_response :unauthorized
  end

  test "login returns a token for a verified user" do
    post api_v1_auth_login_url,
         params: { email: users(:alice).email, password: "password123" },
         as: :json
    assert_response :success
    assert JSON.parse(response.body)["token"].present?
  end

  test "verify with a valid token marks the user verified and returns a token" do
    user = users(:unverified)
    post api_v1_auth_verify_url, params: { token: user.email_verification_token }, as: :json
    assert_response :success
    assert JSON.parse(response.body)["token"].present?
    assert user.reload.email_verified?
  end

  test "verify with an invalid token is rejected" do
    post api_v1_auth_verify_url, params: { token: "bogus-token" }, as: :json
    assert_response :unprocessable_entity
  end

  test "full signup, verify, login flow" do
    post api_v1_auth_signup_url,
         params: { email: "flow@example.com", password: "password123" },
         as: :json
    token = JSON.parse(response.body)["verification_token"]

    post api_v1_auth_login_url,
         params: { email: "flow@example.com", password: "password123" },
         as: :json
    assert_response :forbidden

    post api_v1_auth_verify_url, params: { token: token }, as: :json
    assert_response :success

    post api_v1_auth_login_url,
         params: { email: "flow@example.com", password: "password123" },
         as: :json
    assert_response :success
  end

  test "me requires authentication" do
    get api_v1_auth_me_url
    assert_response :unauthorized
  end

  test "me rejects a malformed token" do
    get api_v1_auth_me_url, headers: { "Authorization" => "Bearer not-a-real-token" }
    assert_response :unauthorized
  end

  test "me returns the current user with a valid token" do
    get api_v1_auth_me_url, headers: auth_headers(users(:alice))
    assert_response :success
    assert_equal users(:alice).email, JSON.parse(response.body)["user"]["email"]
  end

  test "signup sends a verification email" do
    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      post api_v1_auth_signup_url,
           params: { email: "mailer@example.com", password: "password123" },
           as: :json
    end
    assert_equal ["mailer@example.com"], ActionMailer::Base.deliveries.last.to
  end

  test "request_password_reset emails a token and returns 200" do
    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      post api_v1_auth_request_password_reset_url,
           params: { email: users(:alice).email }, as: :json
    end
    assert_response :success
    assert users(:alice).reload.password_reset_token.present?
  end

  test "request_password_reset returns 200 for an unknown email without sending" do
    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      post api_v1_auth_request_password_reset_url,
           params: { email: "nobody@example.com" }, as: :json
    end
    assert_response :success
  end

  test "reset_password with a valid token updates the password and returns a JWT" do
    user = users(:alice)
    user.start_password_reset!
    post api_v1_auth_reset_password_url,
         params: { token: user.password_reset_token, password: "newpassword1" },
         as: :json
    assert_response :success
    assert JSON.parse(response.body)["token"].present?
    assert user.reload.authenticate("newpassword1")
    assert_nil user.password_reset_token
  end

  test "reset_password rejects an invalid token" do
    post api_v1_auth_reset_password_url,
         params: { token: "bogus-token", password: "newpassword1" }, as: :json
    assert_response :unprocessable_entity
  end

  test "reset_password rejects an expired token" do
    user = users(:alice)
    user.start_password_reset!
    user.update!(password_reset_sent_at: 3.hours.ago)
    post api_v1_auth_reset_password_url,
         params: { token: user.password_reset_token, password: "newpassword1" },
         as: :json
    assert_response :unprocessable_entity
  end

  test "reset_password rejects a short password" do
    user = users(:alice)
    user.start_password_reset!
    post api_v1_auth_reset_password_url,
         params: { token: user.password_reset_token, password: "abc" }, as: :json
    assert_response :unprocessable_entity
  end

  test "reset_password verifies a previously unverified user" do
    user = users(:unverified)
    user.start_password_reset!
    post api_v1_auth_reset_password_url,
         params: { token: user.password_reset_token, password: "newpassword1" },
         as: :json
    assert_response :success
    assert user.reload.email_verified?
  end
end
