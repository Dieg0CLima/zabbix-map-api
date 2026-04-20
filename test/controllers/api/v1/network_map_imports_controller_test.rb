require "test_helper"

class Api::V1::NetworkMapImportsControllerTest < ActionDispatch::IntegrationTest
  test "preview returns normalized payload and does not persist map" do
    organization = Organization.create!(name: "Org Import Preview API #{SecureRandom.hex(3)}")
    user = User.create!(email: "import.preview@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user: user, organization: organization, role: "editor")

    auth_header = sign_in_and_fetch_auth_header(user: user, organization: organization)

    post "/api/v1/network_maps/imports/preview", params: {
      provider: "kmz",
      input: sample_kml("Mapa Preview API")
    }.merge(organization_id: organization.id), headers: {
      "Authorization" => auth_header
    }, as: :json

    assert_response :ok
    payload = response.parsed_body.fetch("data")
    assert_equal "created", payload.dig("summary", "map")
    assert_equal "kmz", payload.dig("normalized_payload", "provider")
    assert_equal "Mapa Preview API", payload.dig("normalized_payload", "map", "name")
    assert_equal 0, organization.network_maps.count
  end

  test "apply persists imported map topology" do
    organization = Organization.create!(name: "Org Import Apply API #{SecureRandom.hex(3)}")
    user = User.create!(email: "import.apply@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user: user, organization: organization, role: "editor")

    auth_header = sign_in_and_fetch_auth_header(user: user, organization: organization)

    post "/api/v1/network_maps/imports/apply", params: {
      provider: "kmz",
      input: sample_kml("Mapa Apply API")
    }.merge(organization_id: organization.id), headers: {
      "Authorization" => auth_header
    }, as: :json

    assert_response :ok
    payload = response.parsed_body.fetch("data")
    assert_equal "created", payload.dig("summary", "map")
    assert_equal "Mapa Apply API", payload["network_map_name"]

    imported_map = organization.network_maps.find(payload["network_map_id"])
    assert_equal 2, imported_map.map_nodes.count
    assert_equal 1, imported_map.network_cables.count
  end

  test "preview returns forbidden for viewer role" do
    organization = Organization.create!(name: "Org Import Viewer API #{SecureRandom.hex(3)}")
    user = User.create!(email: "import.viewer@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user: user, organization: organization, role: "viewer")

    auth_header = sign_in_and_fetch_auth_header(user: user, organization: organization)

    post "/api/v1/network_maps/imports/preview", params: {
      provider: "kmz",
      input: sample_kml("Mapa Viewer API"),
      organization_id: organization.id
    }, headers: {
      "Authorization" => auth_header
    }, as: :json

    assert_response :forbidden
    assert_equal "Insufficient permissions", response.parsed_body["error"]
  end

  private

  def sign_in_and_fetch_auth_header(user:, organization:)
    post "/api/v1/users/sign_in", params: {
      user: {
        email: user.email,
        password: "Password!123",
        organization_id: organization.id
      }
    }, as: :json

    response.headers["Authorization"]
  end

  def sample_kml(map_name)
    <<~XML
      <kml xmlns="http://www.opengis.net/kml/2.2">
        <Document>
          <name>#{map_name}</name>
          <Placemark>
            <name>Link Principal</name>
            <LineString>
              <coordinates>
                -46.6300,-23.5500,0 -46.6200,-23.5600,0
              </coordinates>
            </LineString>
          </Placemark>
        </Document>
      </kml>
    XML
  end
end
