module Auth
  module Ldap
    class Config
      def self.current
        raw = Rails.application.config_for(:ldap)
        persisted = LdapSetting.first
        raw = persisted.to_ldap_config_hash if persisted.present?
        new(raw)
      end

      def initialize(raw)
        @raw = (raw || {}).deep_symbolize_keys
      end

      def enabled?
        cast_bool(@raw[:enabled])
      end

      def allow_sign_up?
        cast_bool(@raw[:allow_sign_up])
      end

      def fallback_to_database_auth?
        cast_bool(@raw.fetch(:fallback_to_database_auth, true))
      end

      def servers
        Array(@raw[:servers]).filter_map do |entry|
          server = entry.deep_symbolize_keys
          next if server[:host].blank?

          {
            host: server[:host].to_s,
            port: server[:port].to_i,
            encryption: normalize_encryption(server[:encryption]),
            bind_dn: server[:bind_dn].to_s,
            bind_password: server[:bind_password].to_s,
            search_base_dns: Array(server[:search_base_dns]).map(&:to_s).reject(&:blank?),
            search_filter: server[:search_filter].presence || "(sAMAccountName=%{login})",
            attributes: (server[:attributes] || {}).deep_symbolize_keys
          }
        end
      end

      private

      def cast_bool(value)
        ActiveModel::Type::Boolean.new.cast(value)
      end

      def normalize_encryption(value)
        mode = value.to_s.strip.downcase
        return nil if mode.blank? || mode == "plain"
        return { method: :simple_tls } if mode.in?([ "tls", "simple_tls", "ldaps" ])
        return { method: :start_tls } if mode == "start_tls"

        nil
      end
    end
  end
end
