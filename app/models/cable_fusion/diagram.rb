module CableFusion
  class Diagram < ApplicationRecord
    self.table_name = "cable_fusion_diagrams"

    STATUSES = %w[draft ready invalid archived].freeze

    belongs_to :network_cable
    belongs_to :published_by_user, class_name: "User", optional: true

    has_many :nodes, class_name: "CableFusion::Node", foreign_key: :diagram_id, dependent: :destroy, inverse_of: :diagram
    has_many :ports, through: :nodes, source: :ports
    has_many :links, class_name: "CableFusion::Link", foreign_key: :diagram_id, dependent: :destroy, inverse_of: :diagram
    has_many :snapshots, class_name: "CableFusion::Snapshot", foreign_key: :diagram_id, dependent: :destroy, inverse_of: :diagram

    validates :status, inclusion: { in: STATUSES }
    validates :version, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  end
end
