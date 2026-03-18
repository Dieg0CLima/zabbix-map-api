class Device < ApplicationRecord
  STATUSES = %w[active inactive maintenance].freeze

  belongs_to :organization
  belongs_to :site, optional: true
  belongs_to :zabbix_host, class_name: "Zabbix::Host", optional: true

  has_many :map_elements, as: :mappable, dependent: :destroy
  has_many :map_element_items, through: :map_elements

  before_validation :assign_external_id

  validates :name, presence: true
  validates :external_id, presence: true, uniqueness: { scope: :organization_id }
  validates :status, inclusion: { in: STATUSES }
  validate :zabbix_host_belongs_to_organization

  private

  def assign_external_id
    self.external_id ||= "device-#{SecureRandom.uuid}"
  end

  def zabbix_host_belongs_to_organization
    return if zabbix_host.blank? || organization.blank?

    unless zabbix_host.zabbix_connection.organization_id == organization_id
      errors.add(:zabbix_host_id, "must belong to the same organization")
    end
  end
end
