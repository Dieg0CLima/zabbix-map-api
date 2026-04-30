class LdapSetting < ApplicationRecord
  encrypts :bind_dn
  encrypts :bind_password

  validates :host, :search_base_dn, :search_filter, :attr_username, :attr_email, :attr_name, presence: true
  validates :port, numericality: { only_integer: true, greater_than: 0 }
  validates :encryption, inclusion: { in: %w[plain start_tls tls] }

  def self.current
    first_or_initialize.tap do |setting|
      setting.assign_defaults if setting.new_record?
    end
  end

  def assign_defaults
    self.host ||= ""
    self.port ||= 389
    self.encryption ||= "start_tls"
    self.search_filter ||= "(sAMAccountName=%{login})"
    self.attr_username ||= "sAMAccountName"
    self.attr_email ||= "mail"
    self.attr_name ||= "displayName"
    self.search_base_dn ||= ""
  end

  def to_ldap_config_hash
    {
      enabled: enabled,
      allow_sign_up: allow_sign_up,
      fallback_to_database_auth: fallback_to_database_auth,
      servers: [
        {
          host: host,
          port: port,
          encryption: encryption,
          bind_dn: bind_dn,
          bind_password: bind_password,
          search_base_dns: [ search_base_dn ],
          search_filter: search_filter,
          attributes: {
            username: attr_username,
            email: attr_email,
            name: attr_name
          }
        }
      ]
    }
  end
end
