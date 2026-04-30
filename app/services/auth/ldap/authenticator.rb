require "net/ldap"

module Auth
  module Ldap
    class Authenticator
      Result = Struct.new(:success?, :email, :name, :login, :error, keyword_init: true)

      def initialize(config: Auth::Ldap::Config.current)
        @config = config
      end

      def call(login:, password:)
        return Result.new(success?: false, error: :disabled) unless @config.enabled?
        return Result.new(success?: false, error: :invalid_credentials) if login.blank? || password.blank?

        @config.servers.each do |server|
          entry = find_entry(server:, login:)
          next if entry.nil?

          return build_success(server:, entry:) if bind_as_user(server:, dn: entry.dn, password:)
        rescue StandardError => e
          Rails.logger.warn("LDAP auth server error: #{e.class}: #{e.message}")
          next
        end

        Result.new(success?: false, error: :invalid_credentials)
      end

      private

      def find_entry(server:, login:)
        ldap = build_ldap(server)
        ldap.auth(server[:bind_dn], server[:bind_password]) if server[:bind_dn].present?

        search_filter = format_filter(server[:search_filter], login)

        server[:search_base_dns].each do |base_dn|
          result = ldap.search(base: base_dn, filter: Net::LDAP::Filter.construct(search_filter))
          entry = Array(result).first
          return entry if entry
        end

        nil
      end

      def build_success(server:, entry:)
        attrs = server[:attributes]
        email_attr = attrs.fetch(:email, "mail")
        name_attr = attrs.fetch(:name, "displayName")
        login_attr = attrs.fetch(:username, "sAMAccountName")

        email = read_attr(entry, email_attr)
        name = read_attr(entry, name_attr)
        login = read_attr(entry, login_attr)

        Result.new(
          success?: true,
          email: email.to_s.downcase.presence,
          name: name,
          login: login
        )
      end

      def bind_as_user(server:, dn:, password:)
        ldap = build_ldap(server)
        ldap.auth(dn, password)
        ldap.bind
      end

      def build_ldap(server)
        Net::LDAP.new(
          host: server[:host],
          port: server[:port],
          encryption: server[:encryption]
        )
      end

      def format_filter(template, login)
        safe_login = login.to_s.gsub("%", "")
        template.gsub("%{login}", safe_login)
      end

      def read_attr(entry, attr_name)
        key = attr_name.to_s
        value = entry[key]&.first
        value.to_s.strip.presence
      end
    end
  end
end
