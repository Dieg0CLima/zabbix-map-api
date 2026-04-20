require "test_helper"

class Tenancy::ResolverTest < ActiveSupport::TestCase
  test "resolves organization by parameter in multi mode" do
    with_tenancy_mode("multi") do
      user = User.create!(email: "tenancy.resolver.multi@example.com", password: "Password!123", password_confirmation: "Password!123")
      first = Organization.create!(name: "Resolver Multi A #{SecureRandom.hex(2)}")
      second = Organization.create!(name: "Resolver Multi B #{SecureRandom.hex(2)}")
      Membership.create!(user: user, organization: first, role: "viewer")
      Membership.create!(user: user, organization: second, role: "editor")

      resolved = Tenancy::Resolver.current_organization(
        user: user,
        params: ActionController::Parameters.new(organization_id: second.id)
      )

      assert_equal second.id, resolved.id
    end
  end

  test "resolves local tenant in single mode" do
    with_tenancy_mode("single") do
      user = User.create!(email: "tenancy.resolver.single@example.com", password: "Password!123", password_confirmation: "Password!123")
      organization = Organization.create!(name: "Resolver Single #{SecureRandom.hex(2)}")
      Membership.create!(user: user, organization: organization, role: "admin")

      resolved = Tenancy::Resolver.current_organization(
        user: user,
        params: ActionController::Parameters.new(organization_id: 999_999)
      )

      assert_equal organization.id, resolved.id
    end
  end

  private

  def with_tenancy_mode(mode)
    previous = ENV["TENANCY_MODE"]
    ENV["TENANCY_MODE"] = mode
    yield
  ensure
    ENV["TENANCY_MODE"] = previous
  end
end
