class NetworkCables::EventTypeInferer
  STATUS_FIELDS = %i[status].freeze
  GEOMETRY_FIELDS = %i[points].freeze
  METADATA_FIELDS = %i[metadata].freeze

  def self.call(before_state:, after_state:)
    return "status_changed" if changed?(STATUS_FIELDS, before_state, after_state)
    return "geometry_changed" if changed?(GEOMETRY_FIELDS, before_state, after_state)
    return "metadata_updated" if changed?(METADATA_FIELDS, before_state, after_state)

    "updated"
  end

  def self.changed?(fields, before_state, after_state)
    fields.any? { |field| before_state[field] != after_state[field] }
  end
  private_class_method :changed?
end
