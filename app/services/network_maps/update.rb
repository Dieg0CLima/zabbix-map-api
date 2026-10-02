class NetworkMaps::Update
  NAME_INDEX = "index_network_maps_on_organization_id_and_name".freeze

  def initialize(network_map:, payload:)
    @network_map = network_map
    @payload = payload
  end

  def call
    @network_map.assign_attributes(normalized_payload)
    @network_map.save!(context: :map_settings)
    @network_map
  rescue ActiveRecord::RecordNotUnique => e
    raise unless e.message.include?(NAME_INDEX)

    # Lost the race on the unique (organization_id, name) index after validation passed.
    @network_map.errors.add(:name, :taken)
    raise ActiveRecord::RecordInvalid, @network_map
  end

  private

  def normalized_payload
    attrs = @payload.to_h.with_indifferent_access
    attrs[:name] = attrs[:name].strip if attrs[:name].is_a?(String)
    attrs[:description] = attrs[:description].strip.presence if attrs[:description].is_a?(String)
    attrs
  end
end
