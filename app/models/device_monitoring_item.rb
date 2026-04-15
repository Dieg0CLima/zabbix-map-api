class DeviceMonitoringItem < ApplicationRecord
  USAGE_VALUES = %w[map indicators observability health].freeze

  belongs_to :profile,
             class_name: "DeviceMonitoringProfile",
             foreign_key: :device_monitoring_profile_id,
             inverse_of: :device_monitoring_items
  belongs_to :zabbix_item, class_name: "Zabbix::Item"

  validates :usage, inclusion: { in: USAGE_VALUES }

  validates :zabbix_item_id, uniqueness: { scope: :device_monitoring_profile_id }
  validates :profile, presence: true

  before_validation :apply_category_hint, if: -> { new_record? }

  delegate :device, to: :profile

  def suggested_alias
    self[:alias].presence || zabbix_item&.name
  end

  private

  def apply_category_hint
    return if zabbix_item_id.blank?

    item = classification_item
    return unless item

    hint = classify_item(item)
    return unless hint

    self.category ||= hint[:category]
    self.subcategory ||= hint[:subcategory]
    self.usage = hint[:usage] if hint[:usage].present?
    self.display_priority = hint[:priority] if display_priority.zero? && hint[:priority].present?
    self.map_visibility = true if hint[:map_visibility]
    self.is_primary_metric = true if hint[:primary] && !is_primary_metric?
    self.is_health_metric = true if hint[:health] && !is_health_metric?
  end

  def classification_item
    return @classification_item if defined?(@classification_item)

    @classification_item = zabbix_item || Zabbix::Item.select(:id, :key_, :name, :units).find_by(id: zabbix_item_id)
  end

  def classify_item(item)
    attrs = {
      key: item.key_,
      name: item.name,
      units: item.units
    }

    Devices::Monitoring::ClassificationHintResolver.for(attrs)
  end
end
