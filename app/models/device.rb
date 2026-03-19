class Device < ApplicationRecord
  ROLES = %w[generic router switch firewall gateway server endpoint olt cto splitter].freeze
  STATUSES = %w[planned active maintenance offline decommissioned].freeze

  belongs_to :organization
  belongs_to :site, optional: true

  has_many :device_interfaces, dependent: :destroy
  has_many :map_nodes, as: :mappable, dependent: :restrict_with_error
  has_many :zabbix_links, as: :linkable, dependent: :restrict_with_error
  has_one :zabbix_host_link,
          -> { where(resource_type: "host").order(id: :desc) },
          as: :linkable,
          class_name: "ZabbixLink",
          inverse_of: :linkable
  has_one :zabbix_connection, through: :zabbix_host_link

  validates :name, presence: true
  validates :role, presence: true, inclusion: { in: ROLES }
  validates :status, inclusion: { in: STATUSES }

  validate :site_must_belong_to_same_organization
  validate :zabbix_host_link_consistency

  def zabbix_connection_id
    zabbix_host_link&.zabbix_connection_id
  end

  def zabbix_host_id
    zabbix_host_link&.external_id
  end

  def zabbix_host_label
    zabbix_host_link&.name.presence || zabbix_host_id
  end

  private

  def site_must_belong_to_same_organization
    return if site.blank? || site.organization_id == organization_id

    errors.add(:site, "must belong to the same organization")
  end

  def zabbix_host_link_consistency
    return if zabbix_host_link.blank?

    unless zabbix_host_link.organization_id == organization_id
      errors.add(:zabbix_connection_id, "must belong to the same organization")
    end

    if zabbix_host_link.external_id.blank?
      errors.add(:zabbix_host_id, "must be present when a Zabbix host is linked")
    end
  end
end
