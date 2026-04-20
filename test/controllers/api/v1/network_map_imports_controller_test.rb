require "test_helper"
require "tempfile"

class Api::V1::NetworkMapImportsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    clear_enqueued_jobs
    clear_performed_jobs
  end

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

  test "preview rejects unsupported file extension" do
    organization = Organization.create!(name: "Org Import Invalid Ext #{SecureRandom.hex(3)}")
    user = User.create!(email: "import.invalid.ext@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user: user, organization: organization, role: "editor")

    auth_header = sign_in_and_fetch_auth_header(user: user, organization: organization)
    upload = build_upload(filename: "payload.png", content: "not-kmz", content_type: "image/png")

    post "/api/v1/network_maps/imports/preview", params: {
      provider: "kmz",
      file: upload,
      organization_id: organization.id
    }, headers: {
      "Authorization" => auth_header
    }

    assert_response :unprocessable_entity
    assert_equal "import_invalid_file_type", response.parsed_body["code"]
  end

  test "preview rejects file larger than configured limit" do
    organization = Organization.create!(name: "Org Import Big File #{SecureRandom.hex(3)}")
    user = User.create!(email: "import.big.file@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user: user, organization: organization, role: "editor")

    auth_header = sign_in_and_fetch_auth_header(user: user, organization: organization)
    original_limit = ENV["IMPORT_MAX_FILE_BYTES"]
    ENV["IMPORT_MAX_FILE_BYTES"] = "10"

    upload = build_upload(filename: "payload.kml", content: sample_kml("Mapa Grande"), content_type: "application/vnd.google-earth.kml+xml")

    post "/api/v1/network_maps/imports/preview", params: {
      provider: "kmz",
      file: upload,
      organization_id: organization.id
    }, headers: {
      "Authorization" => auth_header
    }

    assert_response :unprocessable_entity
    assert_equal "import_file_too_large", response.parsed_body["code"]
  ensure
    ENV["IMPORT_MAX_FILE_BYTES"] = original_limit
  end

  test "apply async enqueues import job and returns polling payload" do
    organization = Organization.create!(name: "Org Import Async #{SecureRandom.hex(3)}")
    user = User.create!(email: "import.async@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user: user, organization: organization, role: "editor")
    auth_header = sign_in_and_fetch_auth_header(user: user, organization: organization)

    assert_enqueued_with(job: Maps::Import::ApplyJob) do
      post "/api/v1/network_maps/imports/apply", params: {
        provider: "kmz",
        input: sample_kml("Mapa Async API"),
        async: true,
        organization_id: organization.id
      }, headers: {
        "Authorization" => auth_header
      }, as: :json
    end

    assert_response :accepted
    payload = response.parsed_body.fetch("data")
    assert_equal "queued", payload["status"]
    assert payload["import_id"].present?
    assert_equal "/api/v1/network_maps/imports/#{payload['import_id']}/status", payload["poll_url"]
  end

  test "status endpoint returns completed async import result" do
    organization = Organization.create!(name: "Org Import Async Status #{SecureRandom.hex(3)}")
    user = User.create!(email: "import.async.status@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user: user, organization: organization, role: "editor")
    auth_header = sign_in_and_fetch_auth_header(user: user, organization: organization)

    post "/api/v1/network_maps/imports/apply", params: {
      provider: "kmz",
      input: sample_kml("Mapa Async Status"),
      async: true,
      organization_id: organization.id
    }, headers: {
      "Authorization" => auth_header
    }, as: :json

    assert_response :accepted
    import_id = response.parsed_body.dig("data", "import_id")

    perform_enqueued_jobs

    get "/api/v1/network_maps/imports/#{import_id}/status", params: {
      organization_id: organization.id
    }, headers: {
      "Authorization" => auth_header
    }, as: :json

    assert_response :ok
    status_payload = response.parsed_body.fetch("data")
    assert_equal "completed", status_payload["status"]
    assert_equal "Mapa Async Status", status_payload["network_map_name"]
    assert status_payload["summary"].present?
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

  def build_upload(filename:, content:, content_type:)
    tempfile = Tempfile.new([ "import-upload", File.extname(filename) ])
    tempfile.binmode
    tempfile.write(content)
    tempfile.rewind

    Rack::Test::UploadedFile.new(tempfile.path, content_type, original_filename: filename)
  end
end
