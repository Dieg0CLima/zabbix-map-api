class Device < ApplicationRecord
  ROLES = %w[generic router switch firewall gateway server endpoint olt cto splitter].freeze
  STATUSES = %w[planned active maintenance offline decommissioned].freeze

  belongs_to :organization
  belongs_to :site, optional: true

  has_many :device_interfaces, dependent: :destroy
  has_many :map_nodes, as: :mappable, dependent: :restrict_with_error
  has_many :zabbix_links, as: :linkable, dependent: :restrict_with_error

  validates :name, presence: true
  validates :role, presence: true
  validates :status, inclusion: { in: STATUSES }

  validate :site_must_belong_to_same_organization

  private

  def site_must_belong_to_same_organization
    return if site.blank? || site.organization_id == organization_id

    errors.add(:site, "must belong to the same organization")
  end
end
