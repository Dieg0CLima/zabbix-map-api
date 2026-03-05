require "test_helper"

class Users::RegisterTest < ActiveSupport::TestCase
  test "registers user with new organization" do
    result = Users::Register.new(
      user_params: { email: "new@example.com", password: "Password!123", password_confirmation: "Password!123" },
      organization_name: "Acme Corp"
    ).call

    assert result.user.persisted?
    assert_equal "new@example.com", result.user.email
    assert_equal "Acme Corp", result.organization.name
    assert_equal "acme-corp", result.organization.slug
    assert_equal "admin", result.membership.role
  end

  test "registers user joining existing organization" do
    existing_org = Organization.create!(name: "Existing Org")

    result = Users::Register.new(
      user_params: { email: "joiner@example.com", password: "Password!123", password_confirmation: "Password!123" },
      organization_id: existing_org.id
    ).call

    assert result.user.persisted?
    assert_equal existing_org.id, result.organization.id
    assert_equal "admin", result.membership.role
  end

  test "registers user without organization" do
    result = Users::Register.new(
      user_params: { email: "solo@example.com", password: "Password!123", password_confirmation: "Password!123" }
    ).call

    assert result.user.persisted?
    assert_nil result.organization
    assert_nil result.membership
  end

  test "rolls back on invalid user" do
    assert_no_difference ["User.count", "Organization.count", "Membership.count"] do
      assert_raises(ActiveRecord::RecordInvalid) do
        Users::Register.new(
          user_params: { email: "", password: "short" },
          organization_name: "Should Not Exist"
        ).call
      end
    end
  end

  test "rolls back organization creation on duplicate email" do
    User.create!(email: "dupe@example.com", password: "Password!123", password_confirmation: "Password!123")

    assert_no_difference "Organization.count" do
      assert_raises(ActiveRecord::RecordInvalid) do
        Users::Register.new(
          user_params: { email: "dupe@example.com", password: "Password!123", password_confirmation: "Password!123" },
          organization_name: "Org That Should Rollback"
        ).call
      end
    end
  end
end
