require "test_helper"

# REQ-006: normalization performed by NetworkMaps::Update before assigning (RN8).
class NetworkMaps::UpdateTest < ActiveSupport::TestCase
  setup do
    @org = Organization.create!(name: "Org Update #{SecureRandom.hex(3)}")
    @map = @org.network_maps.create!(name: "Mapa #{SecureRandom.hex(3)}", description: "antes")
  end

  test "CA2: trims the name and turns a blank description into nil" do
    NetworkMaps::Update.new(network_map: @map, payload: { name: "  Rede Leste  ", description: "   " }).call

    assert_equal "Rede Leste", @map.reload.name
    assert_nil @map.description
  end

  test "CA2: works with string keys and ActionController::Parameters (v2 and legacy controllers)" do
    params = ActionController::Parameters.new(network_map: { name: "  Via Params  ", description: "  texto  " }).require(:network_map).permit(:name, :description)

    NetworkMaps::Update.new(network_map: @map, payload: params).call

    assert_equal "Via Params", @map.reload.name
    assert_equal "texto", @map.description
  end

  test "CA2: a payload without name/description leaves them untouched (characterization)" do
    name = @map.name
    NetworkMaps::Update.new(network_map: @map, payload: { active_base_layer: "dark" }).call

    assert_equal "dark", @map.reload.active_base_layer
    assert_equal name, @map.name
    assert_equal "antes", @map.description
  end

  test "CA4: raises RecordInvalid for a changed name longer than 255" do
    assert_raises(ActiveRecord::RecordInvalid) { NetworkMaps::Update.new(network_map: @map, payload: { name: "n" * 256 }).call }
  end

  test "CA8: a RecordNotUnique from the index becomes a RecordInvalid with a taken error on name (no 500)" do
    competitor = @org.network_maps.create!(name: "Disputado")
    error = nil
    Thread.current[:skip_uniqueness_validation] = true
    begin
      error = assert_raises(ActiveRecord::RecordInvalid) { NetworkMaps::Update.new(network_map: @map, payload: { name: competitor.name }).call }
    ensure
      Thread.current[:skip_uniqueness_validation] = false
    end

    assert_equal :taken, error.record.errors.details[:name].first[:error]
  end
end
