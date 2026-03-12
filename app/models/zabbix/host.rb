module Zabbix
  class Host < ApplicationRecord
    self.table_name = "zabbix_hosts"

    belongs_to :zabbix_connection

    has_many :items,
             class_name: "Zabbix::Item",
             foreign_key: :zabbix_host_id,
             dependent: :destroy,
             inverse_of: :host

    has_many :map_nodes,
             foreign_key: :zabbix_host_id,
             dependent: :nullify,
             inverse_of: :zabbix_host

    validates :hostid, presence: true, uniqueness: { scope: :zabbix_connection_id }
    validates :name, presence: true
  end
end
