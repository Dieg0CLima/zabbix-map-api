ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"

module ActiveSupport
  class TestCase
    # DRb-based parallelization is unstable in some container runtimes.
    # Opt-in with PARALLEL_TESTS=1 when needed.
    parallelize(workers: :number_of_processors) if ENV["PARALLEL_TESTS"] == "1"

    # Fixtures are opt-in per test class; global loading can break FK checks
    # when integration tests create records outside fixture-managed tables.

    # Add more helper methods to be used by all tests here...
  end
end
