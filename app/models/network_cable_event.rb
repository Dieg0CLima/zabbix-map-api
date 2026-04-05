class NetworkCableEvent < ApplicationRecord
  EVENT_TYPES = %w[
    created
    updated
    deleted
    metadata_updated
    status_changed
    geometry_changed
    incident
    maintenance
    deactivated
  ].freeze

  belongs_to :network_map
  belongs_to :network_cable, optional: true

  validates :event_type, inclusion: { in: EVENT_TYPES }
  validates :occurred_at, presence: true
end
