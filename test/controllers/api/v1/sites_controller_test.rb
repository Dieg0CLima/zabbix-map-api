require "test_helper"

class Api::V1::SitesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Org Sites Test #{rand(10_000)}")
    @user = User.create!(
      email: "sites.editor.#{rand(9999)}@example.com",
      password: "Password!123",
      password_confirmation: "Password!123"
    )
    Membership.create!(user: @user, organization: @organization, role: "editor")

    post "/api/v1/users/sign_in", params: {
      user: {
        email: @user.email,
        password: "Password!123",
        organization_id: @organization.id
      }
    }, as: :json

    @auth_header = response.headers["Authorization"]
  end

  test "index returns sites for the organization" do
    @organization.sites.create!(name: "Site SP")
    @organization.sites.create!(name: "Site RJ")

    get "/api/v1/sites",
        params: { organization_id: @organization.id },
        headers: { "Authorization" => @auth_header },
        as: :json

    assert_response :ok
    data = response.parsed_body.fetch("data")
    assert_equal 2, data.length
    names = data.map { |s| s["name"] }
    assert_includes names, "Site SP"
    assert_includes names, "Site RJ"
  end

  test "create generates external_id and returns it as id" do
    post "/api/v1/sites",
         params: {
           site: { name: "Site Centro", lat: -23.55, lng: -46.63 },
           organization_id: @organization.id
         },
         headers: { "Authorization" => @auth_header },
         as: :json

    assert_response :created
    data = response.parsed_body.fetch("data")
    assert data["external_id"].present?
    assert_match(/\Asite-/, data["external_id"])
    assert_equal "Site Centro", data["name"]
  end

  test "create validates name presence" do
    post "/api/v1/sites",
         params: {
           site: { name: "" },
           organization_id: @organization.id
         },
         headers: { "Authorization" => @auth_header },
         as: :json

    assert_response :unprocessable_entity
  end

  test "update changes site attributes" do
    site = @organization.sites.create!(name: "Site Antigo")

    patch "/api/v1/sites/#{site.external_id}",
          params: {
            site: { name: "Site Novo", address: "Rua das Flores, 123" },
            organization_id: @organization.id
          },
          headers: { "Authorization" => @auth_header },
          as: :json

    assert_response :ok
    data = response.parsed_body.fetch("data")
    assert_equal "Site Novo", data["name"]
    assert_equal "Rua das Flores, 123", data["address"]
  end

  test "destroy removes the site" do
    site = @organization.sites.create!(name: "Site to Delete")

    delete "/api/v1/sites/#{site.external_id}",
           params: { organization_id: @organization.id },
           headers: { "Authorization" => @auth_header },
           as: :json

    assert_response :no_content
    assert_not Site.exists?(site.id)
  end

  test "show returns a single site" do
    site = @organization.sites.create!(name: "Site Show", lat: -23.5, lng: -46.6)

    get "/api/v1/sites/#{site.external_id}",
        params: { organization_id: @organization.id },
        headers: { "Authorization" => @auth_header },
        as: :json

    assert_response :ok
    data = response.parsed_body.fetch("data")
    assert_equal site.id, data["id"]
    assert_equal "Site Show", data["name"]
  end
end
