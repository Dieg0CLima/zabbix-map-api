class Device < ApplicationRecord
  DEVICE_TYPES = %w[switch router server firewall gateway olt cto splitter other].freeze
  STATUSES = %w[active planned maintenance retired].freeze

  belongs_to :organization
  belongs_to :site, optional: true

  has_many :map_nodes, dependent: :nullify
  has_many :source_network_links,
           class_name: "NetworkLink",
           foreign_key: :source_device_id,
           inverse_of: :source_device,
           dependent: :nullify
  has_many :target_network_links,
           class_name: "NetworkLink",
           foreign_key: :target_device_id,
           inverse_of: :target_device,
           dependent: :nullify

  before_validation :resolve_site_external_id
  before_validation :apply_defaults

  validates :external_id, presence: true, uniqueness: { scope: :organization_id }
  validates :name, presence: true
  validates :device_type, inclusion: { in: DEVICE_TYPES }
  validates :status, inclusion: { in: STATUSES }

  def site_id=(value)
    @site_external_id = nil

    if value.is_a?(String) && value.present? && !value.match?(/\A\d+\z/)
      @site_external_id = value
      return super(nil)
    end

    super(value)
  end

  private

  def resolve_site_external_id
    return if @site_external_id.blank? || organization.blank?

    self.site = organization.sites.find_by(external_id: @site_external_id)
    return if site.present?

    errors.add(:site_id, "must reference an existing site external_id")
  end

  def apply_defaults
    self.external_id ||= "device-#{SecureRandom.uuid}"
    self.device_type ||= "other"
  end
end
