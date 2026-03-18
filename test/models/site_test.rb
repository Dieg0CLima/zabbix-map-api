require "test_helper"

class SiteTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Org Test Site")
  end

  test "generates external_id when not provided" do
    site = @organization.sites.create!(name: "Site SP")

    assert site.external_id.present?
    assert_match(/\Asite-/, site.external_id)
  end

  test "requires name" do
    site = @organization.sites.new
    assert_not site.valid?
    assert_includes site.errors[:name], "can't be blank"
  end

  test "enforces external_id uniqueness within organization" do
    @organization.sites.create!(name: "Site A", external_id: "ext-001")

    duplicate = @organization.sites.new(name: "Site B", external_id: "ext-001")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:external_id], "has already been taken"
  end

  test "allows same external_id across organizations" do
    other_org = Organization.create!(name: "Other Org")
    @organization.sites.create!(name: "Site A", external_id: "ext-001")
    site_other = other_org.sites.new(name: "Site B", external_id: "ext-001")

    assert site_other.valid?
  end

  test "validates status inclusion" do
    site = @organization.sites.new(name: "Site", status: "invalid_status")
    assert_not site.valid?
    assert site.errors[:status].present?
  end

  test "accepts valid statuses" do
    %w[active inactive maintenance].each do |status|
      site = @organization.sites.new(name: "Site #{status}", status: status)
      assert site.valid?, "expected status '#{status}' to be valid: #{site.errors.full_messages}"
    end
  end

  test "accepts lat/lng within valid ranges" do
    site = @organization.sites.new(name: "Site", lat: -23.55, lng: -46.63)
    assert site.valid?, site.errors.full_messages.to_s
  end

  test "rejects invalid lat" do
    site = @organization.sites.new(name: "Site", lat: 91, lng: 0)
    assert_not site.valid?
    assert site.errors[:lat].present?
  end

  test "has many devices" do
    site = @organization.sites.create!(name: "Site")
    assert_respond_to site, :devices
  end

  test "has many map_elements as mappable" do
    site = @organization.sites.create!(name: "Site")
    assert_respond_to site, :map_elements
  end
end
