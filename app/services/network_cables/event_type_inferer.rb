class NetworkCables::EventTypeInferer
  STATUS_FIELDS = %i[status].freeze
  METADATA_FIELDS = %i[label color metadata].freeze

  def self.infer(previous_state:, current_state:, points_changed:)
    return "status_changed" if changed?(STATUS_FIELDS, previous_state, current_state)
    return "geometry_changed" if points_changed
    return "metadata_updated" if changed?(METADATA_FIELDS, previous_state, current_state)

    "updated"
  end

  def self.changed?(fields, previous_state, current_state)
    fields.any? { |field| previous_state[field] != current_state[field] }
  end
  private_class_method :changed?
end
