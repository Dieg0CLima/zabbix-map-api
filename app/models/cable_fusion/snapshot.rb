module CableFusion
  class Snapshot < ApplicationRecord
    self.table_name = "cable_fusion_snapshots"

    belongs_to :diagram, class_name: "CableFusion::Diagram", inverse_of: :snapshots
    belongs_to :created_by_user, class_name: "User", optional: true

    validates :version, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :payload, presence: true
  end
end
