require "test_helper"

class Maps::Import::StatusStoreTest < ActiveSupport::TestCase
  test "tracks queued running and completed lifecycle" do
    organization = Organization.create!(name: "Org Import Status #{SecureRandom.hex(3)}")
    import_id = SecureRandom.uuid

    Maps::Import::StatusStore.enqueue!(
      organization: organization,
      import_id: import_id,
      provider: "kmz",
      mode: "apply_async",
      requested_by_user_id: 123
    )

    queued = Maps::Import::StatusStore.fetch(organization: organization, import_id: import_id)
    assert_equal "queued", queued[:status]

    Maps::Import::StatusStore.running!(organization: organization, import_id: import_id)
    running = Maps::Import::StatusStore.fetch(organization: organization, import_id: import_id)
    assert_equal "running", running[:status]
    assert running[:started_at].present?

    fake_result = Struct.new(:summary, :report, :network_map).new(
      { map: "created" },
      { import_id: import_id },
      Struct.new(:id, :name).new(77, "Mapa Async")
    )

    Maps::Import::StatusStore.completed!(organization: organization, import_id: import_id, result: fake_result)
    completed = Maps::Import::StatusStore.fetch(organization: organization, import_id: import_id)

    assert_equal "completed", completed[:status]
    assert_equal 77, completed[:network_map_id]
    assert_equal "Mapa Async", completed[:network_map_name]
    assert_equal "created", completed.dig(:summary, :map)
  end
end
