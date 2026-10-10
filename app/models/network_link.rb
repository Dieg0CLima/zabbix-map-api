class NetworkLink < ApplicationRecord
  belongs_to :organization
  belongs_to :source_device, class_name: "Device", optional: true
  belongs_to :target_device, class_name: "Device", optional: true

  scope :for_device, ->(device_id) { where(source_device_id: device_id).or(where(target_device_id: device_id)) }
end
