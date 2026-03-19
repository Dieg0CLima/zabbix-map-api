class ZabbixLink < ApplicationRecord
  RESOURCE_TYPES = %w[host item trigger interface host_group tag].freeze

  belongs_to :organization
  belongs_to :zabbix_connection
  belongs_to :linkable, polymorphic: true

  has_many :map_monitoring_bindings, dependent: :nullify

  validates :resource_type, inclusion: { in: RESOURCE_TYPES }
  validates :external_id, presence: true

  validate :linkable_organization_must_match

  private

  def linkable_organization_must_match
    return if linkable.blank?
    return unless linkable.respond_to?(:organization_id)
    return if linkable.organization_id == organization_id

    errors.add(:linkable, "must belong to the same organization")
  end
end
