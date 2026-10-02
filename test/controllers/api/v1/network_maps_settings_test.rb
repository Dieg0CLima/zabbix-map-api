require "test_helper"

# REQ-006 (API): edit name/description of a map (PATCH /api/v1/network_maps/:id), capabilities and error codes.
# "(characterization)" marks behavior that exists today and must keep passing; the rest is new behavior.
# Ambiguous/invisible Unicode is always built from code points, never typed as a literal.
class Api::V1::NetworkMapsSettingsTest < ActionDispatch::IntegrationTest
  # Shared with the ActiveRecord uniqueness validator so a test can simulate the race (CA8): when the flag is set,
  # the Rails-level uniqueness check is skipped and only the unique index answers.
  module SkippableUniqueness
    def validate_each(record, attribute, value)
      return if Thread.current[:skip_uniqueness_validation]

      super
    end
  end
  ActiveRecord::Validations::UniquenessValidator.prepend(SkippableUniqueness)

  ZWJ = [ 0x200D ].pack("U").freeze
  ZWNJ = [ 0x200C ].pack("U").freeze
  LS = [ 0x2028 ].pack("U").freeze
  PS = [ 0x2029 ].pack("U").freeze
  BIDI = ((0x202A..0x202E).to_a + (0x2066..0x2069).to_a).map { |cp| [ cp ].pack("U") }.freeze
  EMOJI = [ 0x1F600 ].pack("U").freeze
  FAMILY = [ 0x1F468, 0x200D, 0x1F469, 0x200D, 0x1F467 ].pack("U*").freeze

  setup do
    @org = Organization.create!(name: "Org Settings #{SecureRandom.hex(3)}")
    @editor = create_user("editor", role: "editor")
    @auth = sign_in(@editor)
    @map = @org.network_maps.create!(name: "Mapa Base #{SecureRandom.hex(3)}", description: "Descrição inicial", source_type: "manual", metadata: { "k" => "v" })
  end

  # ---- CA1: edit ----

  test "CA1: PATCH name and description returns 200 with the serialized map and changes nothing else" do
    @map.update_columns(updated_at: 2.days.ago)
    before = @map.reload.attributes.slice("metadata", "active_base_layer", "zabbix_connection_id", "source_type", "created_at")

    patch_map(@map, name: "Rede Norte", description: "Mapa da região norte")

    assert_response :ok
    data = response.parsed_body["data"]
    assert_equal "Rede Norte", data["name"]
    assert_equal "Mapa da região norte", data["description"]
    assert_equal "manual", data["source_type"]
    assert_operator Time.zone.parse(data["updated_at"]), :>, 1.day.ago
    after = @map.reload.attributes.slice("metadata", "active_base_layer", "zabbix_connection_id", "source_type", "created_at")
    assert_equal before, after
    assert_equal "Rede Norte", @map.name
  end

  # ---- CA2: normalization ----

  test "CA2: name is stored trimmed" do
    patch_map(@map, name: "  Rede Sul  ")

    assert_response :ok
    assert_equal "Rede Sul", @map.reload.name
    assert_equal "Rede Sul", response.parsed_body.dig("data", "name")
  end

  test "CA2: an empty or whitespace-only description is stored as null" do
    [ "", "   ", "#{9.chr} #{10.chr} " ].each do |blank|
      @map.update_columns(description: "algo")
      patch_map(@map, description: blank)

      assert_response :ok, "description=#{blank.inspect}"
      assert_nil @map.reload.description
      assert_nil response.parsed_body.dig("data", "description")
    end
  end

  test "CA2: line breaks (LF and CRLF) and tabs inside the description are preserved (characterization)" do
    text = "linha 1#{10.chr}linha 2#{13.chr}#{10.chr}linha 3#{9.chr}com tab"

    patch_map(@map, description: text)

    assert_response :ok
    assert_equal text, @map.reload.description
  end

  # ---- CA3: required name ----

  test "CA3: an empty or whitespace-only name is rejected with source name and code blank; nothing changes" do
    original = @map.name
    [ "", "   ", "#{9.chr}  " ].each do |blank|
      patch_map(@map, name: blank, description: "outra")

      assert_response :unprocessable_entity, "name=#{blank.inspect}"
      assert_equal "VALIDATION_ERROR", response.parsed_body["code"]
      assert_includes error_pairs, [ "name", "blank" ]
      assert_equal original, @map.reload.name
      assert_equal "Descrição inicial", @map.description
    end
  end

  # ---- CA4: name limit ----

  test "CA4: a name with 255 characters is accepted (characterization of the boundary)" do
    name = "n" * 255
    patch_map(@map, name: name)

    assert_response :ok
    assert_equal name, @map.reload.name
  end

  test "CA4: a name with 256 characters (after trim) is rejected with source name and code too_long" do
    patch_map(@map, name: "  #{'n' * 256}  ")

    assert_response :unprocessable_entity
    assert_includes error_pairs, [ "name", "too_long" ]
    assert_not_equal "n" * 256, @map.reload.name
  end

  test "CA4: a legacy map whose name is longer than 255 can still have only its description edited" do
    @map.update_column(:name, "L" * 300)

    patch_map(@map, name: "L" * 300, description: "só a descrição")

    assert_response :ok
    assert_equal "só a descrição", @map.reload.description
    assert_equal 300, @map.name.length
  end

  test "CA4: editing only the description (name omitted) of a legacy map with a long name succeeds" do
    @map.update_column(:name, "L" * 300)

    patch_map(@map, description: "sem enviar o nome")

    assert_response :ok
    assert_equal "sem enviar o nome", @map.reload.description
  end

  # ---- CA5: description limit ----

  test "CA5: a description with 2000 characters is accepted; 2001 is rejected with source description and code too_long" do
    patch_map(@map, description: "d" * 2000)
    assert_response :ok
    assert_equal 2000, @map.reload.description.length

    patch_map(@map, description: "d" * 2001)
    assert_response :unprocessable_entity
    assert_includes error_pairs, [ "description", "too_long" ]
    assert_equal 2000, @map.reload.description.length
  end

  test "CA5: a legacy map whose description is longer than 2000 can still have only its name edited" do
    @map.update_column(:description, "D" * 3000)

    patch_map(@map, name: "Novo Nome Legado")

    assert_response :ok
    assert_equal "Novo Nome Legado", @map.reload.name
    assert_equal 3000, @map.description.length
  end

  # ---- CA6: characters ----

  test "CA6: control characters, U+2028, U+2029 and bidi formatting in the name are rejected with code invalid_characters" do
    bad = [ "a#{7.chr}b", "a#{27.chr}b", "a#{127.chr}b", "a#{10.chr}b", "a#{13.chr}b", "a#{9.chr}b", "a#{LS}b", "a#{PS}b" ] + BIDI.map { |c| "a#{c}b" }
    bad.each do |value|
      patch_map(@map, name: value)

      assert_response :unprocessable_entity, "name codepoints=#{value.codepoints.inspect}"
      assert_includes error_pairs, [ "name", "invalid_characters" ]
    end
  end

  test "CA6: the same forbidden characters in the description are rejected, except LF, CR and tab" do
    bad = [ "a#{7.chr}b", "a#{27.chr}b", "a#{127.chr}b", "a#{LS}b", "a#{PS}b" ] + BIDI.map { |c| "a#{c}b" }
    bad.each do |value|
      patch_map(@map, description: value)

      assert_response :unprocessable_entity, "description codepoints=#{value.codepoints.inspect}"
      assert_includes error_pairs, [ "description", "invalid_characters" ]
    end

    patch_map(@map, description: "a#{10.chr}b#{13.chr}c#{9.chr}d")
    assert_response :ok
  end

  test "CA6: ZWJ, ZWNJ and emoji are accepted in the name and in the description" do
    [ "Rede #{EMOJI}", "Fam#{FAMILY}", "ab#{ZWNJ}cd", "ab#{ZWJ}cd" ].each_with_index do |value, i|
      patch_map(@map, name: "#{value} #{i}", description: value)

      assert_response :ok, "value codepoints=#{value.codepoints.inspect}"
      assert_equal "#{value} #{i}", @map.reload.name
      assert_equal value, @map.description
    end
  end

  # ---- CA7: duplicated name ----

  test "CA7: a name already used by another map of the same organization is rejected with source name and code taken" do
    other = @org.network_maps.create!(name: "Rede Repetida")

    patch_map(@map, name: "Rede Repetida")

    assert_response :unprocessable_entity
    assert_includes error_pairs, [ "name", "taken" ]
    taken = response.parsed_body["errors"].find { |e| e["code"] == "taken" }
    assert_equal "has already been taken", taken["detail"]
    assert_equal "name", taken["source"]
    assert_not_equal "Rede Repetida", @map.reload.name
    assert_equal "Rede Repetida", other.reload.name
  end

  test "CA7: the comparison is exact and trimmed — differing case is allowed, surrounding spaces are not a difference" do
    @org.network_maps.create!(name: "Rede")

    patch_map(@map, name: "rede")
    assert_response :ok

    patch_map(@map, name: "  Rede  ")
    assert_response :unprocessable_entity
    assert_includes error_pairs, [ "name", "taken" ]
  end

  test "CA7: the same name in another organization is allowed (characterization)" do
    other_org = Organization.create!(name: "Org Settings B #{SecureRandom.hex(3)}")
    other_org.network_maps.create!(name: "Nome Compartilhado")

    patch_map(@map, name: "Nome Compartilhado")

    assert_response :ok
    assert_equal "Nome Compartilhado", @map.reload.name
  end

  test "CA7: keeping the map's own current name is allowed (characterization)" do
    patch_map(@map, name: @map.name, description: "nova descrição")

    assert_response :ok
    assert_equal "nova descrição", @map.reload.description
  end

  # ---- CA8: race ----

  test "CA8: a unique-index violation between validation and UPDATE answers 422 taken (not 500) and keeps the previous name" do
    competitor = @org.network_maps.create!(name: "Nome Disputado")
    previous = @map.name

    response_status = nil
    Thread.current[:skip_uniqueness_validation] = true
    begin
      patch_map(@map, name: "Nome Disputado")
      response_status = response.status
    ensure
      Thread.current[:skip_uniqueness_validation] = false
    end

    assert_equal 422, response_status
    assert_equal "VALIDATION_ERROR", response.parsed_body["code"]
    assert_includes error_pairs, [ "name", "taken" ]
    assert_equal previous, @map.reload.name
    assert_equal "Nome Disputado", competitor.reload.name
  end

  # ---- CA9: organization isolation ----

  test "CA9: PATCH and GET of a map from another organization or a nonexistent id return 404 without changing anything (characterization)" do
    other_org = Organization.create!(name: "Org Settings C #{SecureRandom.hex(3)}")
    foreign = other_org.network_maps.create!(name: "Mapa Alheio", description: "intacto")
    missing = NetworkMap.maximum(:id).to_i + 1000

    [ foreign.id, missing ].each do |id|
      patch "/api/v1/network_maps/#{id}", params: { organization_id: @org.id, network_map: { name: "Invadido" } }, headers: @auth, as: :json
      assert_response :not_found, "PATCH id=#{id}"
      assert_equal "NOT_FOUND", response.parsed_body["code"]
      assert_equal "Record not found", response.parsed_body.dig("errors", 0, "detail")

      get "/api/v1/network_maps/#{id}", params: { organization_id: @org.id }, headers: @auth
      assert_response :not_found, "GET id=#{id}"
    end
    assert_equal "Mapa Alheio", foreign.reload.name
    assert_equal "intacto", foreign.description
  end

  # ---- CA10: authorization ----

  test "CA10: viewer gets 403 on PATCH and nothing changes (characterization)" do
    viewer_auth = sign_in(create_user("viewer", role: "viewer"))

    patch_map(@map, { name: "Tentativa" }, auth: viewer_auth)

    assert_response :forbidden
    assert_equal "FORBIDDEN", response.parsed_body["code"]
    assert_not_equal "Tentativa", @map.reload.name
  end

  test "CA10: unauthenticated PATCH gets 401 (characterization)" do
    patch "/api/v1/network_maps/#{@map.id}", params: { organization_id: @org.id, network_map: { name: "Anon" } }, as: :json

    assert_response :unauthorized
    assert_not_equal "Anon", @map.reload.name
  end

  test "CA10: organization admin, editor and global admin may PATCH (characterization)" do
    {
      "admin membership" => sign_in(create_user("orgadmin", role: "admin")),
      "editor membership" => @auth,
      "global admin (viewer membership)" => sign_in(create_user("globaladmin", role: "viewer", admin: true))
    }.each_with_index do |(label, auth), i|
      patch_map(@map, { name: "Por #{label} #{i}" }, auth: auth)

      assert_response :ok, label
      assert_equal "Por #{label} #{i}", @map.reload.name
    end
  end

  # ---- CA11: capabilities ----

  test "CA11: GET /network_maps and /:id expose meta.capabilities.can_edit — true for editor, org admin and global admin; false for viewer" do
    {
      "editor" => [ @auth, true ],
      "org admin" => [ sign_in(create_user("orgadmin2", role: "admin")), true ],
      "global admin" => [ sign_in(create_user("globaladmin2", role: "viewer", admin: true)), true ],
      "viewer" => [ sign_in(create_user("viewer2", role: "viewer")), false ]
    }.each do |label, (auth, expected)|
      get "/api/v1/network_maps", params: { organization_id: @org.id }, headers: auth
      assert_response :ok, label
      assert_equal expected, response.parsed_body.dig("meta", "capabilities", "can_edit"), "index #{label}"

      get "/api/v1/network_maps/#{@map.id}", params: { organization_id: @org.id }, headers: auth
      assert_response :ok, label
      assert_equal expected, response.parsed_body.dig("meta", "capabilities", "can_edit"), "show #{label}"
    end
  end

  test "CA11: editor_state's can_edit_map follows the same rule, including the global admin (D1)" do
    {
      "editor" => [ @auth, true ],
      "global admin" => [ sign_in(create_user("globaladmin3", role: "viewer", admin: true)), true ],
      "viewer" => [ sign_in(create_user("viewer3", role: "viewer")), false ]
    }.each do |label, (auth, expected)|
      get "/api/v1/network_maps/#{@map.id}/editor_state", params: { organization_id: @org.id }, headers: auth

      assert_response :ok, label
      assert_equal expected, response.parsed_body.dig("data", "capabilities", "can_edit_map"), label
    end
  end

  test "CA11: the existing index payload keeps its data (characterization)" do
    get "/api/v1/network_maps", params: { organization_id: @org.id }, headers: @auth

    assert_response :ok
    row = response.parsed_body["data"].find { |m| m["id"] == @map.id }
    assert_equal @map.name, row["name"]
    assert_equal "Descrição inicial", row["description"]
  end

  # ---- CA12: code per error ----

  test "CA12: validation errors carry source, detail and code (PATCH)" do
    patch_map(@map, name: "")

    assert_response :unprocessable_entity
    error = response.parsed_body["errors"].find { |e| e["source"] == "name" }
    assert_equal "blank", error["code"]
    assert_equal "can't be blank", error["detail"]
  end

  test "CA12: other endpoints using render_record_errors also get code while keeping source and detail (POST map, POST site)" do
    post "/api/v1/network_maps", params: { organization_id: @org.id, network_map: { name: "" } }, headers: @auth, as: :json
    assert_response :unprocessable_entity
    error = response.parsed_body["errors"].find { |e| e["source"] == "name" }
    assert_equal "can't be blank", error["detail"]
    assert_equal "blank", error["code"]

    post "/api/v1/network_maps", params: { organization_id: @org.id, network_map: { name: @map.name } }, headers: @auth, as: :json
    assert_response :unprocessable_entity
    taken = response.parsed_body["errors"].find { |e| e["source"] == "name" }
    assert_equal "has already been taken", taken["detail"]
    assert_equal "taken", taken["code"]
    assert_equal "VALIDATION_ERROR", response.parsed_body["code"]
  end

  # ---- CA13: layer PATCH compatibility (characterization) ----

  test "CA13: the full layer payload with an unchanged legacy long name still updates the layer (characterization)" do
    @map.update_column(:name, "L" * 300)

    patch_map(@map, name: "L" * 300, description: @map.description, metadata: { "k" => "v" }, source_type: "manual", active_base_layer: "dark", zabbix_connection_id: nil)

    assert_response :ok
    assert_equal "dark", @map.reload.active_base_layer
    assert_equal 300, @map.name.length
  end

  test "CA13: a PATCH with only active_base_layer changes only that field (characterization)" do
    patch_map(@map, active_base_layer: "satellite")

    assert_response :ok
    @map.reload
    assert_equal "satellite", @map.active_base_layer
    assert_equal "Descrição inicial", @map.description
    assert_equal({ "k" => "v" }, @map.metadata)
  end

  # ---- CA14: legacy ----

  test "CA14: legacy PATCH with an invalid changed name answers in the legacy validation format" do
    patch "/api/v1/legacy/network_maps/#{@map.id}", params: { organization_id: @org.id, network_map: { name: "n" * 256 } }, headers: @auth, as: :json

    assert_response :unprocessable_entity
    assert_equal "VALIDATION_ERROR", response.parsed_body["code"]
    assert response.parsed_body["details"].key?("name"), "legacy format keeps details keyed by attribute"
    assert_not_equal "n" * 256, @map.reload.name
  end

  test "CA14: legacy PATCH that does not change name/description behaves as today, even with a legacy long name (characterization)" do
    @map.update_column(:name, "L" * 300)

    patch "/api/v1/legacy/network_maps/#{@map.id}", params: { organization_id: @org.id, network_map: { active_base_layer: "light" } }, headers: @auth, as: :json

    assert_response :ok
    assert_equal "light", @map.reload.active_base_layer
  end

  # ---- CA15: create and import unchanged (characterization) ----

  test "CA15: POST /network_maps with a 300-character name keeps creating the map (characterization)" do
    post "/api/v1/network_maps", params: { organization_id: @org.id, network_map: { name: "c" * 300 } }, headers: @auth, as: :json

    assert_response :created
    assert_equal 300, @org.network_maps.find(response.parsed_body.dig("data", "id")).name.length
  end

  test "CA15: the KMZ import keeps accepting a 300-character map name (characterization)" do
    kml = <<~XML
      <kml xmlns="http://www.opengis.net/kml/2.2"><Document><name>#{'k' * 300}</name>
        <Placemark><name>Link</name><LineString><coordinates>-46.63,-23.55,0 -46.62,-23.56,0</coordinates></LineString></Placemark>
      </Document></kml>
    XML

    post "/api/v1/network_maps/imports/apply", params: { provider: "kmz", input: kml, organization_id: @org.id }, headers: @auth, as: :json

    assert_response :ok
    assert_equal 300, response.parsed_body.dig("data", "network_map_name").length
  end

  private

  def create_user(label, role:, admin: false)
    user = User.create!(email: "#{label}.#{SecureRandom.hex(4)}@example.com", password: "Password!123", password_confirmation: "Password!123", admin: admin)
    Membership.create!(user: user, organization: @org, role: role)
    user
  end

  def sign_in(user)
    post "/api/v1/users/sign_in", params: { user: { email: user.email, password: "Password!123", organization_id: @org.id } }, as: :json
    { "Authorization" => response.headers["Authorization"] }
  end

  def patch_map(map, attrs = {}, auth: @auth, **keyword_attrs)
    patch "/api/v1/network_maps/#{map.id}", params: { organization_id: @org.id, network_map: attrs.merge(keyword_attrs) }, headers: auth, as: :json
  end

  def error_pairs
    Array(response.parsed_body["errors"]).map { |e| [ e["source"], e["code"] ] }
  end
end
