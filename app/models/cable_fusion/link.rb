module CableFusion
  class Link < ApplicationRecord
    self.table_name = "cable_fusion_links"

    LINK_KINDS = %w[splice patch pass_through reserve terminated].freeze
    FIBER_SIDES = %w[a b internal none].freeze
    STATUSES = %w[draft active disabled].freeze

    belongs_to :diagram, class_name: "CableFusion::Diagram", inverse_of: :links
    belongs_to :source_port, class_name: "CableFusion::Port"
    belongs_to :target_port, class_name: "CableFusion::Port"

    validates :link_kind, inclusion: { in: LINK_KINDS }
    validates :status, inclusion: { in: STATUSES }
    validates :fiber_side, inclusion: { in: FIBER_SIDES }, allow_blank: true
    validates :fiber_number, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validate :ports_must_be_distinct

    private

    def ports_must_be_distinct
      return if source_port_id != target_port_id

      errors.add(:target_port_id, "must be different from source_port_id")
    end
  end
end
