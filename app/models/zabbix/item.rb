module Zabbix
  class Item < ApplicationRecord
    self.table_name = "zabbix_items"

    belongs_to :zabbix_connection
    belongs_to :host,
               class_name: "Zabbix::Host",
               foreign_key: :zabbix_host_id,
               inverse_of: :items,
               optional: true

    validates :itemid, presence: true, uniqueness: { scope: :zabbix_connection_id }
    validates :key_, presence: true
    validates :name, presence: true
  end
end
