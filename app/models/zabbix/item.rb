module Zabbix
  class Item < ApplicationRecord
    self.table_name = "zabbix_items"

    belongs_to :zabbix_connection
    belongs_to :host,
               class_name: "Zabbix::Host",
               foreign_key: :zabbix_host_id,
               inverse_of: :items,
               optional: true

    has_many :map_node_items, foreign_key: :zabbix_item_id, dependent: :destroy, inverse_of: :zabbix_item
    has_many :network_cable_items, foreign_key: :zabbix_item_id, dependent: :destroy, inverse_of: :zabbix_item

    validates :itemid, presence: true, uniqueness: { scope: :zabbix_connection_id }
    validates :key_, presence: true
    validates :name, presence: true

    # Backward-compatibility for legacy call sites/tests still assigning
    # `zabbix_host` as an association object.
    def zabbix_host
      host
    end

    def zabbix_host=(value)
      case value
      when Zabbix::Host
        self[:zabbix_host_id] = value.id
      when nil, ""
        self[:zabbix_host_id] = nil
      else
        self[:zabbix_host_id] = value
      end
    end
  end
end
