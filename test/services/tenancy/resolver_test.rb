require "test_helper"

class Tenancy::ResolverTest < ActiveSupport::TestCase
  test "uses TENANCY_MODE to switch between multi and single" do
    previous_mode = ENV["TENANCY_MODE"]
    ENV["TENANCY_MODE"] = "multi"

    assert_equal "multi", Tenancy::Resolver.tenancy_mode
    assert_equal false, Tenancy::Resolver.single_tenant_mode?

    ENV["TENANCY_MODE"] = "single"

    assert_equal "single", Tenancy::Resolver.tenancy_mode
    assert_equal true, Tenancy::Resolver.single_tenant_mode?
  ensure
    ENV["TENANCY_MODE"] = previous_mode
  end

  test "resolves configured single-tenant organization when TENANCY_ORGANIZATION_ID is present" do
    user = User.create!(email: "tenancy.resolver.configured@example.com", password: "Password!123", password_confirmation: "Password!123")
    first = Organization.create!(name: "Resolver Config A #{SecureRandom.hex(2)}")
    second = Organization.create!(name: "Resolver Config B #{SecureRandom.hex(2)}")
    Membership.create!(user: user, organization: first, role: "viewer")
    Membership.create!(user: user, organization: second, role: "editor")

    previous = ENV["TENANCY_ORGANIZATION_ID"]
    previous_mode = ENV["TENANCY_MODE"]
    ENV["TENANCY_MODE"] = "single"
    ENV["TENANCY_ORGANIZATION_ID"] = second.id.to_s

    resolved = Tenancy::Resolver.current_organization(
      user: user,
      params: ActionController::Parameters.new(organization_id: first.id)
    )

    assert_equal second.id, resolved.id
  ensure
    ENV["TENANCY_ORGANIZATION_ID"] = previous
    ENV["TENANCY_MODE"] = previous_mode
  end

  test "resolves user current organization when no configured tenant exists" do
    user = User.create!(email: "tenancy.resolver.default@example.com", password: "Password!123", password_confirmation: "Password!123")
    organization = Organization.create!(name: "Resolver Default #{SecureRandom.hex(2)}")
    Membership.create!(user: user, organization: organization, role: "admin")

    previous = ENV["TENANCY_ORGANIZATION_ID"]
    previous_mode = ENV["TENANCY_MODE"]
    ENV["TENANCY_MODE"] = "single"
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
    ENV["TENANCY_MODE"] = previous_mode
  end

  test "multi tenant mode respects requested organization for admin and memberships for regular users" do
    admin = User.create!(email: "tenancy.resolver.admin@example.com", password: "Password!123", password_confirmation: "Password!123", admin: true)
    user = User.create!(email: "tenancy.resolver.user@example.com", password: "Password!123", password_confirmation: "Password!123")
    first = Organization.create!(name: "Resolver Multi A #{SecureRandom.hex(2)}")
    second = Organization.create!(name: "Resolver Multi B #{SecureRandom.hex(2)}")
    Membership.create!(user: user, organization: first, role: "viewer")
    Membership.create!(user: user, organization: second, role: "editor")

    previous_mode = ENV["TENANCY_MODE"]
    ENV["TENANCY_MODE"] = "multi"

    admin_resolved = Tenancy::Resolver.current_organization(
      user: admin,
      params: ActionController::Parameters.new(organization_id: second.id)
    )
    user_resolved = Tenancy::Resolver.current_organization(
      user: user,
      params: ActionController::Parameters.new(organization_id: second.id)
    )

    assert_equal second.id, admin_resolved.id
    assert_equal second.id, user_resolved.id
  ensure
    ENV["TENANCY_MODE"] = previous_mode
  end
end
