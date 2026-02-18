class ZabbixConnection < ApplicationRecord
  STATUSES = %w[active inactive error].freeze
  CONNECTION_MODES = %w[api database hybrid].freeze
  DB_ADAPTERS = %w[postgresql mysql].freeze

  belongs_to :organization

  has_many :network_maps, dependent: :nullify
  has_many :zabbix_hosts, class_name: "Zabbix::Host", dependent: :destroy
  has_many :zabbix_items, class_name: "Zabbix::Item", dependent: :destroy

  encrypts :api_token
  encrypts :db_password

  validates :name, presence: true, uniqueness: { scope: :organization_id }
  validates :status, inclusion: { in: STATUSES }
  validates :connection_mode, inclusion: { in: CONNECTION_MODES }

  validates :base_url, presence: true, if: :api_enabled?

  validates :db_adapter, inclusion: { in: DB_ADAPTERS }, if: :db_enabled?
  validates :db_host, :db_port, :db_name, :db_username, presence: true, if: :db_enabled?
  validates :db_port, numericality: { only_integer: true, greater_than: 0 }, if: :db_enabled?

  def api_enabled?
    connection_mode.in?(%w[api hybrid])
  end

  def db_enabled?
    connection_mode.in?(%w[database hybrid])
  end
end
