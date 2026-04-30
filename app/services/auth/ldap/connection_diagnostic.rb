require "net/ldap"

module Auth
  module Ldap
    class ConnectionDiagnostic
      Result = Struct.new(
        :success?,
        :auth_success?,
        :stage,
        :code,
        :detail,
        :hint,
        :user_information,
        :ldap_attributes,
        :ldap_groups,
        :search_attempts,
        :resolved_dn_candidates,
        keyword_init: true
      )

      def initialize(config: Auth::Ldap::Config.current)
        @config = config
      end

      def call(login:, password:)
        log_info("LDAP diagnostic started", login:)
        return failure(stage: "configuration", code: "disabled", detail: "LDAP desabilitado.") unless @config.enabled?

        server = @config.servers.first
        return failure(stage: "configuration", code: "missing_server", detail: "Nenhum servidor LDAP configurado.") if server.blank?

        ldap = build_ldap(server)

        bind_ok = bind_service_account(ldap, server)
        log_info("LDAP service bind result", bind_dn: server[:bind_dn], success: bind_ok)
        unless bind_ok
          return failure(
            stage: "service_bind",
            code: "service_bind_failed",
            detail: "Falha no bind do usuário de serviço LDAP.",
            hint: "Revise bind_dn/bind_password e política de bind do AD."
          )
        end

        search_attempts = []
        entry = find_entry(ldap, server, login, search_attempts)
        resolved_dn_candidates = build_dn_candidates(server, login)
        log_debug("LDAP resolved DN candidates", count: resolved_dn_candidates.size, candidates: resolved_dn_candidates)

        if entry.nil?
          entry = find_entry_by_dn_candidates(server, resolved_dn_candidates)
        end

        unless entry
          return failure(
            stage: "user_lookup",
            code: "user_not_found",
            detail: "Usuário não encontrado com base/filter informados.",
            hint: "Revise search_base_dn, search_filter e login informado.",
            search_attempts:,
            resolved_dn_candidates:
          )
        end

        user_info = extract_user_information(entry, server)
        groups = extract_groups(entry)
        attrs = extract_attributes(entry)

        auth_success = bind_as_user(server, entry.dn, password)
        log_info("LDAP user bind result", login:, dn: entry.dn.to_s, success: auth_success)
        code = auth_success ? "ok" : "invalid_credentials"
        detail = auth_success ? "Usuário autenticado com sucesso." : "Senha do usuário de teste inválida (ou bind de usuário negado)."

        Result.new(
          success?: auth_success,
          auth_success?: auth_success,
          stage: "user_auth",
          code:,
          detail:,
          hint: auth_success ? nil : "Mesmo com falha de senha, os dados de usuário/grupos foram retornados para diagnóstico.",
          user_information: user_info,
          ldap_attributes: attrs,
          ldap_groups: groups,
          search_attempts:,
          resolved_dn_candidates:
        )
      rescue StandardError => e
        log_warn("LDAP diagnostic runtime error", error_class: e.class.name, error_message: e.message)
        failure(stage: "runtime", code: "ldap_error", detail: "Erro LDAP: #{e.class}: #{e.message}")
      end

      private

      def failure(stage:, code:, detail:, hint: nil, search_attempts: [], resolved_dn_candidates: [])
        Result.new(
          success?: false,
          auth_success?: false,
          stage:,
          code:,
          detail:,
          hint:,
          user_information: {},
          ldap_attributes: {},
          ldap_groups: [],
          search_attempts:,
          resolved_dn_candidates:
        )
      end

      def bind_service_account(ldap, server)
        if server[:bind_dn].present?
          ldap.auth(server[:bind_dn], server[:bind_password])
        end
        ldap.bind
      end

      def find_entry(ldap, server, login, search_attempts)
        filter = Net::LDAP::Filter.construct(format_filter(server[:search_filter], login))

        server[:search_base_dns].each do |base_dn|
          result = ldap.search(base: base_dn, filter: filter)
          search_attempts << { base_dn:, filter: format_filter(server[:search_filter], login), count: Array(result).size }
          log_debug("LDAP search attempt", base_dn:, filter: format_filter(server[:search_filter], login), count: Array(result).size)
          entry = Array(result).first
          return entry if entry
        end

        nil
      end

      def build_dn_candidates(server, login)
        attribute = server.dig(:attributes, :username).presence || "sAMAccountName"
        server[:search_base_dns].map { |base_dn| "#{attribute}=#{login},#{base_dn}" }
      end

      def find_entry_by_dn_candidates(server, dn_candidates)
        dn_candidates.each do |candidate_dn|
          ldap = build_ldap(server)
          ldap.auth(server[:bind_dn], server[:bind_password]) if server[:bind_dn].present?
          result = ldap.search(base: candidate_dn, scope: Net::LDAP::SearchScope_BaseObject)
          log_debug("LDAP DN candidate attempt", candidate_dn:, count: Array(result).size)
          entry = Array(result).first
          return entry if entry
        end
        nil
      end

      def bind_as_user(server, dn, password)
        return false if password.to_s.empty?

        ldap = build_ldap(server)
        ldap.auth(dn, password)
        ldap.bind
      end

      def extract_user_information(entry, server)
        attrs = server[:attributes]

        {
          dn: entry.dn.to_s,
          username: read_attr(entry, attrs.fetch(:username, "sAMAccountName")),
          email: read_attr(entry, attrs.fetch(:email, "mail")),
          name: read_attr(entry, attrs.fetch(:name, "displayName"))
        }
      end

      def extract_attributes(entry)
        entry.to_h.each_with_object({}) do |(key, values), acc|
          acc[key.to_s] = Array(values).map(&:to_s)
        end
      end

      def extract_groups(entry)
        Array(entry["memberOf"]).map(&:to_s)
      end

      def build_ldap(server)
        Net::LDAP.new(host: server[:host], port: server[:port], encryption: server[:encryption])
      end

      def format_filter(template, login)
        safe_login = login.to_s.gsub("%", "")
        template.gsub("%{login}", safe_login)
      end

      def read_attr(entry, attr_name)
        Array(entry[attr_name.to_s]).first.to_s.presence
      end

      def log_info(message, data = {})
        Rails.logger.info("[LDAP_DIAGNOSTIC] #{message} #{data.to_json}")
      end

      def log_debug(message, data = {})
        Rails.logger.debug("[LDAP_DIAGNOSTIC] #{message} #{data.to_json}")
      end

      def log_warn(message, data = {})
        Rails.logger.warn("[LDAP_DIAGNOSTIC] #{message} #{data.to_json}")
      end
    end
  end
end
