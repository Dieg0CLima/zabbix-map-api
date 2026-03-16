class Device < ApplicationRecord
  EQUIPMENT_KINDS = %w[switch router server firewall gateway endpoint zabbix_host olt cto splitter].freeze

  belongs_to :organization
  belongs_to :site, optional: true
  has_many :map_nodes, dependent: :nullify

  validates :name, :external_id, presence: true
  validates :external_id, uniqueness: { scope: :organization_id }

  before_validation :apply_defaults

  private

  def apply_defaults
    self.external_id ||= "device-#{SecureRandom.uuid}"
  end
end
