module CableFusion
  class Node < ApplicationRecord
    self.table_name = "cable_fusion_nodes"

    NODE_TYPES = %w[splice_box dio splitter tray cto termination_box reserve].freeze

    belongs_to :diagram, class_name: "CableFusion::Diagram", inverse_of: :nodes
    has_many :ports, class_name: "CableFusion::Port", foreign_key: :node_id, dependent: :destroy, inverse_of: :node

    validates :node_type, inclusion: { in: NODE_TYPES }
    validates :x, :y, numericality: true
    validates :rotation, numericality: true
  end
end
