require "test_helper"

class Sites::DropdownPayloadBuilderTest < ActiveSupport::TestCase
  test "builds dropdown payload for site" do
    organization = Organization.create!(name: "Org Sites Dropdown")
    site = organization.sites.create!(name: "Site Alpha", slug: "site-alpha")

    payload = Sites::DropdownPayloadBuilder.new(site).call

    assert_equal site.id, payload[:value]
    assert_equal "Site Alpha", payload[:label]
    assert_equal "site-alpha", payload[:code]
    assert_equal "site-alpha", payload.dig(:meta, :slug)
  end
end
