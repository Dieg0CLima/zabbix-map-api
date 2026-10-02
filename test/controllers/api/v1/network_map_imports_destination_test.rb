require "test_helper"

# REQ-005 (API): destination of the KMZ import (network_map_name, on_name_conflict, network_map_id coverage).
# Tests marked "(characterization)" describe behavior that already exists and must keep passing; the rest
# describe the new behavior and are expected to fail until it is implemented.
class Api::V1::NetworkMapImportsDestinationTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  IMPORT_PATH = "/api/v1/network_maps/imports".freeze

  setup do
    clear_enqueued_jobs
    clear_performed_jobs
    @org = Organization.create!(name: "Org Dest A #{SecureRandom.hex(3)}")
    @editor = create_user("editor", org: @org, role: "editor")
    @auth = { "Authorization" => sign_in(@editor, @org) }
  end

  # ---- CA1 / CA3 / CA10: compatibility (characterization) ----

  test "CA1: without the new params, apply updates in silence the map with the same name as the KMZ (characterization)" do
    existing = @org.network_maps.create!(name: "Mapa Compat")

    apply(kml: sample_kml("Mapa Compat"))

    assert_response :ok
    assert_equal "updated", data.dig("summary", "map")
    assert_equal existing.id, data["network_map_id"]
    assert_equal 1, @org.network_maps.where(name: "Mapa Compat").count
  end

  test "CA1: without the new params, preview reports updated for an existing name and created for a new one (characterization)" do
    existing = @org.network_maps.create!(name: "Mapa Compat Prev")

    preview(kml: sample_kml("Mapa Compat Prev"))
    assert_response :ok
    assert_equal "updated", data.dig("target_map", "action")
    assert_equal existing.id, data.dig("target_map", "network_map_id")

    preview(kml: sample_kml("Mapa Totalmente Novo"))
    assert_equal "created", data.dig("summary", "map")
    assert_equal "created", data.dig("target_map", "action")
    assert_nil data.dig("target_map", "network_map_id")
  end

  test "CA1: async without the new params still updates by name and completes (characterization)" do
    existing = @org.network_maps.create!(name: "Mapa Compat Async")

    apply(kml: sample_kml("Mapa Compat Async"), extra: { async: true })
    assert_response :accepted
    import_id = data["import_id"]
    perform_enqueued_jobs

    get "#{IMPORT_PATH}/#{import_id}/status", params: { organization_id: @org.id }, headers: @auth
    assert_response :ok
    assert_equal "completed", data["status"]
    assert_equal existing.id, data["network_map_id"]
  end

  test "CA10: on_name_conflict=update or omitted updates the existing map (characterization of omitted; update is new but equivalent)" do
    existing = @org.network_maps.create!(name: "Mapa Update Policy")

    apply(kml: sample_kml("Mapa Update Policy"), extra: { on_name_conflict: "update" })

    assert_response :ok
    assert_equal "updated", data.dig("summary", "map")
    assert_equal existing.id, data["network_map_id"]
  end

  test "CA3: blank or missing network_map_name falls back to the KMZ name" do
    [ nil, "", "   " ].each_with_index do |blank, i|
      kml_name = "Mapa Fallback #{i}"
      extra = blank.nil? ? {} : { network_map_name: blank }
      apply(kml: sample_kml(kml_name), extra: extra)

      assert_response :ok, "blank=#{blank.inspect}"
      assert_equal "created", data.dig("summary", "map")
      assert_equal kml_name, data["network_map_name"]
    end
  end

  # ---- CA2: informed name ----

  test "CA2: apply with network_map_name creates the map with the trimmed name" do
    apply(kml: sample_kml("Nome do KMZ"), extra: { network_map_name: "  Rede Norte  " })

    assert_response :ok
    assert_equal "created", data.dig("summary", "map")
    assert_equal "Rede Norte", data["network_map_name"]
    assert @org.network_maps.exists?(name: "Rede Norte")
    assert_not @org.network_maps.exists?(name: "Nome do KMZ")
  end

  test "CA2: preview with network_map_name reports the target map and persists nothing" do
    preview(kml: sample_kml("Nome do KMZ"), extra: { network_map_name: "  Rede Norte  " })

    assert_response :ok
    assert_equal({ "action" => "created", "network_map_id" => nil, "network_map_name" => "Rede Norte" }, data["target_map"])
    assert_equal 0, @org.network_maps.count
  end

  test "CA2: async with network_map_name creates the map with that name" do
    apply(kml: sample_kml("Nome do KMZ"), extra: { network_map_name: "Rede Async", async: true })
    assert_response :accepted
    import_id = data["import_id"]
    perform_enqueued_jobs

    get "#{IMPORT_PATH}/#{import_id}/status", params: { organization_id: @org.id }, headers: @auth
    assert_equal "completed", data["status"]
    assert_equal "Rede Async", data["network_map_name"]
  end

  test "CA2/preview: target_map.network_map_name is the name of the map that will be updated" do
    @org.network_maps.create!(name: "Mapa Existente Prev")

    preview(kml: sample_kml("Mapa Existente Prev"))

    assert_equal "Mapa Existente Prev", data.dig("target_map", "network_map_name")
  end

  # ---- CA4: invalid name ----

  test "CA4: names of 255 characters are accepted (boundary)" do
    name = "n" * 255
    apply(kml: sample_kml("Nome do KMZ"), extra: { network_map_name: name })

    assert_response :ok
    assert_equal name, data["network_map_name"]
  end

  test "CA4: a name with more than 255 characters (after trim) is rejected in preview, apply and async" do
    too_long = "n" * 256
    [ [ :preview, {} ], [ :apply, {} ], [ :apply, { async: true } ] ].each do |action, extra|
      before_maps = @org.network_maps.count
      send(action, kml: sample_kml("Nome do KMZ"), extra: extra.merge(network_map_name: "  #{too_long}  "))

      assert_response :unprocessable_entity, "#{action} #{extra}"
      assert_equal "import_invalid_map_name", response.parsed_body["code"]
      assert_equal 255, response.parsed_body.dig("details", "max_length")
      assert_equal before_maps, @org.network_maps.count
      assert_no_enqueued_jobs
    end
  end

  test "CA4: control characters and line breaks in the name are rejected" do
    [ "Rede#{10.chr}Norte", "Rede#{13.chr}Norte", "Rede#{9.chr}Norte", "Rede#{7.chr}Norte", "Rede#{0.chr}Norte" ].each do |bad|
      apply(kml: sample_kml("Nome do KMZ"), extra: { network_map_name: bad })

      assert_response :unprocessable_entity, "name=#{bad.inspect}"
      assert_equal "import_invalid_map_name", response.parsed_body["code"]
    end
    assert_equal 0, @org.network_maps.count
  end

  test "CA4: an invalid name in async enqueues no job and creates no status" do
    apply(kml: sample_kml("Nome do KMZ"), extra: { network_map_name: "x#{10.chr}y", async: true })

    assert_response :unprocessable_entity
    assert_equal "import_invalid_map_name", response.parsed_body["code"]
    assert_no_enqueued_jobs
    assert_equal 0, @org.network_maps.count
  end

  # ---- CA5 / CA12: name + network_map_id ----

  test "CA5: network_map_id together with network_map_name is rejected (preview, apply, async) without persisting or enqueueing" do
    target = @org.network_maps.create!(name: "Mapa Alvo CA5")
    [ [ :preview, {} ], [ :apply, {} ], [ :apply, { async: true } ] ].each do |action, extra|
      send(action, kml: sample_kml("Nome do KMZ"), extra: extra.merge(network_map_id: target.id, network_map_name: "Outro Nome"))

      assert_response :unprocessable_entity, "#{action} #{extra}"
      assert_equal "import_map_name_with_target", response.parsed_body["code"]
      assert_no_enqueued_jobs
    end
    assert_equal 0, target.reload.map_nodes.count
    assert_equal "Mapa Alvo CA5", target.name
    assert_equal 1, @org.network_maps.count
  end

  test "CA12: with network_map_id, on_name_conflict has no effect (the explicit target is updated even if the KMZ name exists)" do
    target = @org.network_maps.create!(name: "Mapa Alvo CA12")
    @org.network_maps.create!(name: "Nome do KMZ CA12")

    apply(kml: sample_kml("Nome do KMZ CA12"), extra: { network_map_id: target.id, on_name_conflict: "fail" })

    assert_response :ok
    assert_equal target.id, data["network_map_id"]
    assert_equal "updated", data.dig("summary", "map")
    assert_equal 2, target.reload.map_nodes.count
  end

  # ---- CA6: existing map as destination (characterization: there was no test with network_map_id) ----

  test "CA6: apply into an existing map keeps its name, merges by external_id and removes nothing (characterization)" do
    target = @org.network_maps.create!(name: "Mapa Destino CA6")

    apply(kml: sample_kml("Nome do KMZ CA6"), extra: { network_map_id: target.id })
    assert_response :ok
    assert_equal "updated", data.dig("summary", "map")
    assert_equal target.id, data["network_map_id"]
    assert_equal "Mapa Destino CA6", data["network_map_name"]
    assert_equal "Mapa Destino CA6", target.reload.name
    assert_equal 2, target.map_nodes.count
    assert_equal 1, target.network_cables.count

    manual = target.map_nodes.create!(external_id: "manual-keep", label: "Manual", node_kind: "generic", x: -23.5, y: -46.6, lat: -23.5, lng: -46.6)
    apply(kml: sample_kml("Nome do KMZ CA6"), extra: { network_map_id: target.id })

    assert_response :ok
    assert_equal 3, target.reload.map_nodes.count
    assert target.map_nodes.exists?(id: manual.id), "pre-existing node must not be removed"
    assert_equal 1, target.network_cables.count, "re-import must not duplicate cables"
    assert_equal 1, @org.network_maps.count
  end

  test "CA6: preview with network_map_id reports updated for that map and persists nothing (characterization)" do
    target = @org.network_maps.create!(name: "Mapa Destino Prev CA6")

    preview(kml: sample_kml("Nome do KMZ"), extra: { network_map_id: target.id })

    assert_response :ok
    assert_equal "updated", data.dig("summary", "map")
    assert_equal target.id, data.dig("target_map", "network_map_id")
    assert_equal 0, target.reload.map_nodes.count
  end

  test "CA6: async into an existing map completes against that map (characterization)" do
    target = @org.network_maps.create!(name: "Mapa Destino Async CA6")

    apply(kml: sample_kml("Nome do KMZ"), extra: { network_map_id: target.id, async: true })
    assert_response :accepted
    import_id = data["import_id"]
    perform_enqueued_jobs

    get "#{IMPORT_PATH}/#{import_id}/status", params: { organization_id: @org.id }, headers: @auth
    assert_equal "completed", data["status"]
    assert_equal target.id, data["network_map_id"]
    assert_equal 2, target.reload.map_nodes.count
  end

  # ---- CA7: network_map_id of another organization / nonexistent (characterization) ----

  test "CA7: network_map_id of another organization or nonexistent returns 404 in preview, apply and async, persisting and enqueueing nothing (characterization)" do
    other_org = Organization.create!(name: "Org Dest B #{SecureRandom.hex(3)}")
    foreign_map = other_org.network_maps.create!(name: "Mapa da B CA7")
    missing_id = NetworkMap.maximum(:id).to_i + 1000

    [ foreign_map.id, missing_id ].each do |map_id|
      [ [ :preview, {} ], [ :apply, {} ], [ :apply, { async: true } ] ].each do |action, extra|
        send(action, kml: sample_kml("Nome do KMZ"), extra: extra.merge(network_map_id: map_id))

        assert_response :not_found, "#{action} #{extra} id=#{map_id}"
        assert_equal "NOT_FOUND", response.parsed_body["code"]
        assert_equal "Record not found", response.parsed_body["message"]
        assert_no_enqueued_jobs
      end
    end
    assert_equal 0, foreign_map.reload.map_nodes.count
    assert_equal 0, @org.network_maps.count
  end

  test "CA7: the 404 for a foreign map is indistinguishable from the 404 for a nonexistent map (characterization)" do
    other_org = Organization.create!(name: "Org Dest B2 #{SecureRandom.hex(3)}")
    foreign_map = other_org.network_maps.create!(name: "Mapa da B CA7b")

    apply(kml: sample_kml("X"), extra: { network_map_id: foreign_map.id })
    foreign_body = response.parsed_body
    apply(kml: sample_kml("X"), extra: { network_map_id: NetworkMap.maximum(:id).to_i + 1000 })

    assert_equal foreign_body, response.parsed_body
  end

  # ---- CA8: same name in another organization (characterization) ----

  test "CA8: a map with the same name in another organization is neither updated nor adopted (characterization)" do
    other_org = Organization.create!(name: "Org Dest B3 #{SecureRandom.hex(3)}")
    foreign_map = other_org.network_maps.create!(name: "Rede X")

    apply(kml: sample_kml("Rede X"))

    assert_response :ok
    assert_equal "created", data.dig("summary", "map")
    assert_not_equal foreign_map.id, data["network_map_id"]
    assert_equal @org.id, NetworkMap.find(data["network_map_id"]).organization_id
    assert_equal 0, foreign_map.reload.map_nodes.count
    assert_equal({}, foreign_map.metadata)
  end

  # ---- CA9 / CA11: name conflict policy ----

  test "CA9: on_name_conflict=fail with an existing name rejects apply with import_map_name_conflict and changes nothing" do
    existing = @org.network_maps.create!(name: "Mapa Repetido")

    apply(kml: sample_kml("Mapa Repetido"), extra: { on_name_conflict: "fail" })

    assert_response :unprocessable_entity
    assert_equal "import_map_name_conflict", response.parsed_body["code"]
    assert_equal existing.id, response.parsed_body.dig("details", "network_map_id")
    assert_equal "Mapa Repetido", response.parsed_body.dig("details", "network_map_name")
    assert_equal 0, existing.reload.map_nodes.count
    assert_equal 0, existing.network_cables.count
    assert_equal({}, existing.metadata)
  end

  test "CA9: the conflict also applies to an informed network_map_name" do
    existing = @org.network_maps.create!(name: "Rede Informada")

    apply(kml: sample_kml("Nome do KMZ"), extra: { network_map_name: "Rede Informada", on_name_conflict: "fail" })

    assert_response :unprocessable_entity
    assert_equal "import_map_name_conflict", response.parsed_body["code"]
    assert_equal existing.id, response.parsed_body.dig("details", "network_map_id")
  end

  test "CA9: preview with on_name_conflict=fail does not fail: it informs updated with id and name" do
    existing = @org.network_maps.create!(name: "Mapa Repetido Prev")

    preview(kml: sample_kml("Mapa Repetido Prev"), extra: { on_name_conflict: "fail" })

    assert_response :ok
    assert_equal({ "action" => "updated", "network_map_id" => existing.id, "network_map_name" => "Mapa Repetido Prev" }, data["target_map"])
  end

  test "CA9: on_name_conflict=fail with a new name creates the map normally" do
    apply(kml: sample_kml("Mapa Sem Conflito"), extra: { on_name_conflict: "fail" })

    assert_response :ok
    assert_equal "created", data.dig("summary", "map")
  end

  test "CA9: the comparison is exact (different case is a different name, as in the unique index)" do
    @org.network_maps.create!(name: "rede")

    apply(kml: sample_kml("Rede"), extra: { on_name_conflict: "fail" })

    assert_response :ok
    assert_equal "created", data.dig("summary", "map")
  end

  test "CA11: an invalid on_name_conflict is rejected with import_invalid_option in preview, apply and async" do
    [ [ :preview, {} ], [ :apply, {} ], [ :apply, { async: true } ] ].each do |action, extra|
      send(action, kml: sample_kml("Nome do KMZ"), extra: extra.merge(on_name_conflict: "replace"))

      assert_response :unprocessable_entity, "#{action} #{extra}"
      assert_equal "import_invalid_option", response.parsed_body["code"]
      assert_equal "on_name_conflict", response.parsed_body.dig("details", "param")
      assert_equal %w[update fail], response.parsed_body.dig("details", "allowed")
      assert_no_enqueued_jobs
    end
    assert_equal 0, @org.network_maps.count
  end

  # ---- CA13 / CA14: async races ----

  test "CA13: async with fail — a map created with that name between enqueue and run makes the job fail without updating it" do
    apply(kml: sample_kml("Mapa Corrida"), extra: { on_name_conflict: "fail", async: true })
    assert_response :accepted
    import_id = data["import_id"]
    concurrent = @org.network_maps.create!(name: "Mapa Corrida")

    perform_enqueued_jobs

    get "#{IMPORT_PATH}/#{import_id}/status", params: { organization_id: @org.id }, headers: @auth
    assert_response :ok
    assert_equal "failed", data["status"]
    assert_equal "import_map_name_conflict", data.dig("error", "code")
    assert_equal 0, concurrent.reload.map_nodes.count
    assert_equal({}, concurrent.metadata)
  end

  test "CA14: async with a valid network_map_id removed before the job runs fails with import_target_map_not_found" do
    target = @org.network_maps.create!(name: "Mapa Removido")
    apply(kml: sample_kml("Nome do KMZ"), extra: { network_map_id: target.id, async: true })
    assert_response :accepted
    import_id = data["import_id"]
    target.destroy!

    begin
      perform_enqueued_jobs
    rescue StandardError
      nil # today the job re-raises after marking the status; the status is what matters here
    end

    get "#{IMPORT_PATH}/#{import_id}/status", params: { organization_id: @org.id }, headers: @auth
    assert_response :ok
    assert_equal "failed", data["status"]
    assert_equal "import_target_map_not_found", data.dig("error", "code")
    assert_equal 0, @org.network_maps.count
  end

  # ---- CA15: atomicity (characterization) ----

  test "CA15: an error during apply with a new name leaves no map, node, cable or site behind (characterization)" do
    failing = ->(*) { raise ActiveRecord::RecordInvalid.new(NetworkCable.new) }

    NetworkCablePoint.stub(:insert_all!, failing) do
      apply(kml: sample_kml("Mapa Atomico"))
    end

    assert_response :unprocessable_entity
    assert_equal "import_apply_failed", response.parsed_body["code"]
    assert_equal 0, @org.network_maps.count
    assert_equal 0, MapNode.joins(:network_map).where(network_maps: { organization_id: @org.id }).count
    assert_equal 0, NetworkCable.joins(:network_map).where(network_maps: { organization_id: @org.id }).count
  end

  # ---- CA16: authorization (characterization of apply/status; preview viewer already covered elsewhere) ----

  test "CA16: viewer gets 403 on preview, apply and status (characterization)" do
    viewer = create_user("viewer", org: @org, role: "viewer")
    viewer_auth = sign_in(viewer, @org)

    post "#{IMPORT_PATH}/preview", params: import_params(kml: sample_kml("V")), headers: { "Authorization" => viewer_auth }, as: :json
    assert_response :forbidden
    post "#{IMPORT_PATH}/apply", params: import_params(kml: sample_kml("V")), headers: { "Authorization" => viewer_auth }, as: :json
    assert_response :forbidden
    get "#{IMPORT_PATH}/#{SecureRandom.uuid}/status", params: { organization_id: @org.id }, headers: { "Authorization" => viewer_auth }
    assert_response :forbidden
    assert_equal 0, @org.network_maps.count
  end

  test "CA16: unauthenticated requests get 401 on preview, apply and status (characterization)" do
    post "#{IMPORT_PATH}/preview", params: import_params(kml: sample_kml("A")), as: :json
    assert_response :unauthorized
    post "#{IMPORT_PATH}/apply", params: import_params(kml: sample_kml("A")), as: :json
    assert_response :unauthorized
    get "#{IMPORT_PATH}/#{SecureRandom.uuid}/status", params: { organization_id: @org.id }
    assert_response :unauthorized
  end

  test "CA16: an organization admin can import (characterization)" do
    admin = create_user("orgadmin", org: @org, role: "admin")

    post "#{IMPORT_PATH}/apply", params: import_params(kml: sample_kml("Mapa Admin")), headers: { "Authorization" => sign_in(admin, @org) }, as: :json

    assert_response :ok
  end

  test "CA16: a viewer cannot use the new params either (still 403, nothing persisted)" do
    viewer = create_user("viewer2", org: @org, role: "viewer")
    post "#{IMPORT_PATH}/apply", params: import_params(kml: sample_kml("V"), extra: { network_map_name: "Rede V", on_name_conflict: "fail" }),
      headers: { "Authorization" => sign_in(viewer, @org) }, as: :json

    assert_response :forbidden
    assert_equal 0, @org.network_maps.count
  end

  # ---- CA17: status isolation (characterization) ----

  test "CA17: another organization (or an unknown import_id) gets 404 'Import status not found' (characterization)" do
    apply(kml: sample_kml("Mapa Status"), extra: { async: true })
    import_id = data["import_id"]
    perform_enqueued_jobs

    other_org = Organization.create!(name: "Org Dest B4 #{SecureRandom.hex(3)}")
    other_editor = create_user("other.editor", org: other_org, role: "editor")
    other_auth = sign_in(other_editor, other_org)

    get "#{IMPORT_PATH}/#{import_id}/status", params: { organization_id: other_org.id }, headers: { "Authorization" => other_auth }
    assert_response :not_found
    assert_equal "Import status not found", response.parsed_body["message"]

    get "#{IMPORT_PATH}/#{SecureRandom.uuid}/status", params: { organization_id: @org.id }, headers: @auth
    assert_response :not_found
    assert_equal "Import status not found", response.parsed_body["message"]

    get "#{IMPORT_PATH}/#{import_id}/status", params: { organization_id: @org.id }, headers: @auth
    assert_response :ok
  end

  # ---- CA18: jobs in flight (characterization) ----

  test "CA18: an ApplyJob enqueued before the deploy (without the new arguments) still runs to completion (characterization)" do
    import_id = SecureRandom.uuid
    Maps::Import::StatusStore.enqueue!(organization: @org, import_id: import_id, provider: "kmz", mode: "apply_async", requested_by_user_id: @editor.id)

    Maps::Import::ApplyJob.perform_now(
      organization_id: @org.id,
      import_id: import_id,
      provider: "kmz",
      input_payload: { kind: "text", data: sample_kml("Mapa Job Antigo") }
    )

    status = Maps::Import::StatusStore.fetch(organization: @org, import_id: import_id)
    assert_equal "completed", status[:status]
    assert_equal "Mapa Job Antigo", status[:network_map_name]
  end

  # ---- CA19: contract and docs ----

  test "CA19: docs/api-contract.md documents the new params, merge semantics and new error codes" do
    docs = File.read(Rails.root.join("docs/api-contract.md"))

    %w[network_map_name on_name_conflict import_invalid_map_name import_map_name_with_target import_invalid_option
       import_map_name_conflict import_target_map_not_found].each do |term|
      assert_includes docs, term, "docs/api-contract.md must mention #{term}"
    end
  end

  private

  def data
    response.parsed_body["data"]
  end

  def create_user(label, org:, role:)
    user = User.create!(email: "#{label}.#{SecureRandom.hex(4)}@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user: user, organization: org, role: role)
    user
  end

  def sign_in(user, org)
    post "/api/v1/users/sign_in", params: { user: { email: user.email, password: "Password!123", organization_id: org.id } }, as: :json
    response.headers["Authorization"]
  end

  def import_params(kml:, extra: {})
    { provider: "kmz", input: kml, organization_id: @org.id }.merge(extra)
  end

  def preview(kml:, extra: {})
    post "#{IMPORT_PATH}/preview", params: import_params(kml: kml, extra: extra), headers: @auth, as: :json
  end

  def apply(kml:, extra: {})
    post "#{IMPORT_PATH}/apply", params: import_params(kml: kml, extra: extra), headers: @auth, as: :json
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
