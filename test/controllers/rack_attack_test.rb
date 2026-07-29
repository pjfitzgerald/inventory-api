require "test_helper"

# Throttling rules live in config/initializers/rack_attack.rb.
class RackAttackTest < ActionDispatch::IntegrationTest
  # A distinct email per attempt, so only the per-IP limit is in play — an
  # attacker spraying one password across many accounts from one host.
  test "login is throttled per IP" do
    20.times do |i|
      post api_v1_auth_login_url,
           params: { email: "spray#{i}@example.com", password: "wrong-password" },
           as: :json
      assert_response :unauthorized
    end

    post api_v1_auth_login_url,
         params: { email: "spray-over@example.com", password: "wrong-password" },
         as: :json

    assert_response :too_many_requests
    assert response.headers["Retry-After"].present?
    assert JSON.parse(response.body)["error"].present?
  end

  # The per-email limit is what stops a distributed attack on one known
  # account, so it has to bite even when every request comes from a new IP.
  test "login is throttled per email address across different IPs" do
    10.times do |i|
      post api_v1_auth_login_url,
           params: { email: users(:alice).email, password: "wrong-password" },
           as: :json,
           env: { "REMOTE_ADDR" => "203.0.113.#{i + 1}" }
      assert_response :unauthorized
    end

    post api_v1_auth_login_url,
         params: { email: users(:alice).email, password: "wrong-password" },
         as: :json,
         env: { "REMOTE_ADDR" => "203.0.113.200" }

    assert_response :too_many_requests
  end

  test "a different email is unaffected by another account's login throttle" do
    10.times do |i|
      post api_v1_auth_login_url,
           params: { email: users(:alice).email, password: "wrong-password" },
           as: :json,
           env: { "REMOTE_ADDR" => "198.51.100.#{i + 1}" }
    end

    post api_v1_auth_login_url,
         params: { email: users(:bob).email, password: "wrong-password" },
         as: :json,
         env: { "REMOTE_ADDR" => "198.51.100.200" }

    assert_response :unauthorized
  end

  # Guards the Rack::Attack::Request#ip override: the API always sits behind a
  # proxy, and if the client IP didn't resolve properly every caller would
  # share one bucket and 25 unrelated clients would trip the 20/minute limit.
  test "separate clients get separate per-IP login budgets" do
    25.times do |i|
      post api_v1_auth_login_url,
           params: { email: "distinct#{i}@example.com", password: "wrong-password" },
           as: :json,
           env: { "REMOTE_ADDR" => "203.0.113.#{i + 1}" }
      assert_response :unauthorized
    end
  end

  test "signup is throttled per IP" do
    5.times do |i|
      post api_v1_auth_signup_url,
           params: { email: "throttle#{i}@example.com", password: "tangerine-shelf-lamp" },
           as: :json
      assert_response :created
    end

    assert_no_difference("User.count") do
      post api_v1_auth_signup_url,
           params: { email: "throttle-over@example.com", password: "tangerine-shelf-lamp" },
           as: :json
    end
    assert_response :too_many_requests
  end

  test "password reset requests are throttled per email address" do
    3.times do |i|
      post api_v1_auth_request_password_reset_url,
           params: { email: users(:alice).email },
           as: :json,
           env: { "REMOTE_ADDR" => "192.0.2.#{i + 1}" }
      assert_response :success
    end

    post api_v1_auth_request_password_reset_url,
         params: { email: users(:alice).email },
         as: :json,
         env: { "REMOTE_ADDR" => "192.0.2.200" }

    assert_response :too_many_requests
  end

  # A CSV / backup import POSTs one item per row, so a restore of a few
  # hundred items must not trip a limit. These endpoints need a valid JWT, so
  # they aren't an anonymous attack surface in the first place.
  test "item writes are not throttled" do
    user = users(:alice)

    40.times do |i|
      post api_v1_items_url,
           params: { item: { name: "Bulk import #{i}" } },
           headers: auth_headers(user),
           as: :json
      assert_response :created
    end
  end
end
