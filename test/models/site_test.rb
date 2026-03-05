require "test_helper"

class SiteTest < ActiveSupport::TestCase
  test "auto generates external_id and validates org scoped uniqueness" do
    organization = Organization.create!(name: "Org Site")
    site = organization.sites.create!(name: "POP SP", status: "active")

    assert_match(/\Asite-/, site.external_id)

    duplicate = organization.sites.new(name: "POP SP", status: "active")
    assert_not duplicate.valid?
  end
end
