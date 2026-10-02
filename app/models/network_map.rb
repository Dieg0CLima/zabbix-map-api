class NetworkMap < ApplicationRecord
  BASE_LAYERS = %w[standard terrain hot cycle light voyager dark satellite streets topo].freeze

  belongs_to :organization
  belongs_to :zabbix_connection, optional: true

  has_many :map_pops, dependent: :destroy
  has_many :map_nodes, dependent: :destroy
  has_many :map_edges, dependent: :destroy
  has_many :map_monitoring_bindings, through: :map_nodes
  has_many :network_cables, dependent: :destroy
  has_many :network_cable_events, dependent: :destroy
  has_many :network_map_snapshots, dependent: :destroy

  # Settings edit (REQ-006): limits and character policy. They only run in the
  # :map_settings context (used by NetworkMaps::Update, not by create/import) and
  # only when the attribute changes, so legacy maps outside the limits stay editable.
  NAME_MAX_LENGTH = 255
  DESCRIPTION_MAX_LENGTH = 2000
  # Control characters (Cc), U+2028/U+2029 and bidirectional formatting
  # (U+202A-U+202E, U+2066-U+2069). ZWJ/ZWNJ and emoji stay allowed.
  FORBIDDEN_NAME_CHARS = /[\p{Cc}\u2028\u2029\u202A-\u202E\u2066-\u2069]/
  # The description additionally allows LF, CR and tab.
  FORBIDDEN_DESCRIPTION_CHARS = /(?![\n\r\t])[\p{Cc}\u2028\u2029\u202A-\u202E\u2066-\u2069]/

  validates :name, presence: true
  validates :name, uniqueness: { scope: :organization_id }
  validates :source_type, inclusion: { in: %w[manual zabbix hybrid] }
  validates :active_base_layer, inclusion: { in: BASE_LAYERS }

  validates :name, length: { maximum: NAME_MAX_LENGTH }, if: :will_save_change_to_name?, on: :map_settings
  validates :description, length: { maximum: DESCRIPTION_MAX_LENGTH }, if: :will_save_change_to_description?, on: :map_settings
  validate :name_characters_allowed, if: :will_save_change_to_name?, on: :map_settings
  validate :description_characters_allowed, if: :will_save_change_to_description?, on: :map_settings

  private

  def name_characters_allowed
    return unless name.to_s.match?(FORBIDDEN_NAME_CHARS)

    errors.add(:name, :invalid_characters, message: "contains invalid characters")
  end

  def description_characters_allowed
    return unless description.to_s.match?(FORBIDDEN_DESCRIPTION_CHARS)

    errors.add(:description, :invalid_characters, message: "contains invalid characters")
  end
end
