ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Rack::Attack's counters live in a process-wide store, so without this a
  # test that posts to /auth/signup would spend the budget of every later
  # test in the same worker (and which tests share a worker depends on the
  # seed). Each test starts from a clean slate.
  setup { Rack::Attack.cache.store.clear }

  # Items live in an inventory and record who created them. Unless a specific
  # inventory is given, put the item in the user's personal one — which is
  # what the app does for anyone who has not shared anything.
  def create_item(user, attributes = {})
    attributes = attributes.dup
    inventory = attributes.delete(:inventory) || user.personal_inventory
    inventory.items.create!(attributes.merge(user: user))
  end

  # Add more helper methods to be used by all tests here...
end

class ActionDispatch::IntegrationTest
  # Authorization header carrying a valid JWT for the given user.
  def auth_headers(user)
    { 'Authorization' => "Bearer #{JsonWebToken.encode({ user_id: user.id })}" }
  end

  # Run the block with Rails.env temporarily set to the given value, for
  # testing production-only behaviour from the test env. Restored on exit
  # even if the block raises.
  def with_rails_env(env)
    original = Rails.env
    Rails.env = env
    yield
  ensure
    Rails.env = original
  end
end
