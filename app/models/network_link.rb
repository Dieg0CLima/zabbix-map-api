class NetworkLink < ApplicationRecord
  LINK_TYPES = %w[fiber copper wireless logical other].freeze
  STATUSES = %w[active planned maintenance disabled].freeze

  belongs_to :organization
  belongs_to :source_device, class_name: "Device", optional: true
  belongs_to :target_device, class_name: "Device", optional: true
  belongs_to :source_site, class_name: "Site", optional: true
  belongs_to :target_site, class_name: "Site", optional: true

  has_many :network_cables, dependent: :nullify

  before_validation :resolve_external_ids
  before_validation :apply_defaults

  validates :external_id, presence: true, uniqueness: { scope: :organization_id }
  validates :link_type, inclusion: { in: LINK_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :bandwidth_mbps, numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }

  validate :source_endpoint_present

  %i[source_device_id target_device_id source_site_id target_site_id].each do |field|
    define_method("#{field}=") do |value|
      instance_variable_set("@#{field}_external_id", nil)

      if value.is_a?(String) && value.present? && !value.match?(/\A\d+\z/)
        instance_variable_set("@#{field}_external_id", value)
        return super(nil)
      end

      super(value)
    end
  end

  private

  def resolve_external_ids
    resolve_external_id(:source_device, Device)
    resolve_external_id(:target_device, Device)
    resolve_external_id(:source_site, Site)
    resolve_external_id(:target_site, Site)
  end

  def resolve_external_id(association, klass)
    external_id = instance_variable_get("@#{association}_id_external_id")
    return if external_id.blank? || organization.blank?

    record = organization.public_send(klass.name.tableize).find_by(external_id: external_id)
    public_send("#{association}=", record)
    return if record.present?

    errors.add("#{association}_id", "must reference an existing #{association} external_id")
  end

  def apply_defaults
    self.external_id ||= "link-#{SecureRandom.uuid}"
  end

  def source_endpoint_present
    return if source_device_id.present? || source_site_id.present?

    errors.add(:base, "source endpoint must be present")
  end
end
