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
end
