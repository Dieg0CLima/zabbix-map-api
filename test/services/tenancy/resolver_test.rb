require "test_helper"

class Tenancy::ResolverTest < ActiveSupport::TestCase
  test "resolves configured single-tenant organization when TENANCY_ORGANIZATION_ID is present" do
    user = User.create!(email: "tenancy.resolver.configured@example.com", password: "Password!123", password_confirmation: "Password!123")
    first = Organization.create!(name: "Resolver Config A #{SecureRandom.hex(2)}")
    second = Organization.create!(name: "Resolver Config B #{SecureRandom.hex(2)}")
    Membership.create!(user: user, organization: first, role: "viewer")
    Membership.create!(user: user, organization: second, role: "editor")

    previous = ENV["TENANCY_ORGANIZATION_ID"]
    ENV["TENANCY_ORGANIZATION_ID"] = second.id.to_s

    resolved = Tenancy::Resolver.current_organization(
      user: user,
      params: ActionController::Parameters.new(organization_id: first.id)
    )

    assert_equal second.id, resolved.id
  ensure
    ENV["TENANCY_ORGANIZATION_ID"] = previous
  end

  test "resolves user current organization when no configured tenant exists" do
    user = User.create!(email: "tenancy.resolver.default@example.com", password: "Password!123", password_confirmation: "Password!123")
    organization = Organization.create!(name: "Resolver Default #{SecureRandom.hex(2)}")
    Membership.create!(user: user, organization: organization, role: "admin")

    previous = ENV["TENANCY_ORGANIZATION_ID"]
    ENV["TENANCY_ORGANIZATION_ID"] = nil

    resolved = Tenancy::Resolver.current_organization(
      user: user,
      params: ActionController::Parameters.new(organization_id: 999_999)
    )

    assert_equal organization.id, resolved.id
    assert_equal true, Tenancy::Resolver.single_tenant_mode?
    assert_equal "single", Tenancy::Resolver.tenancy_mode
  ensure
    ENV["TENANCY_ORGANIZATION_ID"] = previous
  end
end
