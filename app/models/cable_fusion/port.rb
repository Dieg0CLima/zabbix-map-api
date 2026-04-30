module CableFusion
  class Port < ApplicationRecord
    self.table_name = "cable_fusion_ports"

    PORT_TYPES = %w[fiber_in fiber_out splitter_in splitter_out patch uplink].freeze

    belongs_to :node, class_name: "CableFusion::Node", inverse_of: :ports

    validates :name, presence: true
    validates :port_type, inclusion: { in: PORT_TYPES }
    validates :capacity, :occupancy_limit, numericality: { only_integer: true, greater_than: 0 }
  end
end
