class DeviceInterface < ApplicationRecord
  belongs_to :device

  has_many :zabbix_links, as: :linkable, dependent: :restrict_with_error

  delegate :organization_id, to: :device

  validates :name, presence: true, uniqueness: { scope: :device_id }
end
