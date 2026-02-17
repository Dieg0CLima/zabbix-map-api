class ZabbixConnection < ApplicationRecord
  STATUSES = %w[active inactive error].freeze

  belongs_to :organization

  has_many :network_maps, dependent: :nullify
  has_many :zabbix_hosts, class_name: "Zabbix::Host", dependent: :destroy
  has_many :zabbix_items, class_name: "Zabbix::Item", dependent: :destroy

  encrypts :api_token

  validates :name, presence: true, uniqueness: { scope: :organization_id }
  validates :base_url, presence: true
  validates :status, inclusion: { in: STATUSES }
end
