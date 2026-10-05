# Test helper (REQ-008): sets/clears ENV["ALLOW_PUBLIC_SIGNUP"] for the duration of a block and always restores the
# previous state (present with its value, or absent), so nothing leaks between tests (random order, optional parallelism).
# Load it with `require_relative` from every test that uses it.
module PublicSignupFlag
  KEY = "ALLOW_PUBLIC_SIGNUP".freeze

  # `value` nil removes the variable (absent); any String sets it verbatim.
  def with_public_signup(value)
    had_key = ENV.key?(KEY)
    previous = ENV[KEY]
    value.nil? ? ENV.delete(KEY) : ENV[KEY] = value
    yield
  ensure
    had_key ? ENV[KEY] = previous : ENV.delete(KEY)
  end
end
