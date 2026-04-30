class Api::V1::LdapSettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :require_admin_membership_or_global_admin!

  def show
    setting = LdapSetting.current
    log_ldap_state("show", setting)
    render json: { data: payload(setting) }, status: :ok
  end

  def update
    setting = LdapSetting.current
    log_ldap_update_request
    setting.assign_attributes(ldap_setting_params)
    setting.updated_by_user_id = current_user.id
    bind_dn_will_change = setting.will_save_change_to_bind_dn?
    bind_password_will_change = setting.will_save_change_to_bind_password?
    setting.save!
    setting.reload
    log_ldap_state(
      "update_after_save",
      setting,
      {
        bind_dn_will_change: bind_dn_will_change,
        bind_password_will_change: bind_password_will_change,
        bind_dn_saved_change: setting.saved_change_to_bind_dn?,
        bind_password_saved_change: setting.saved_change_to_bind_password?
      }
    )

    render json: { data: payload(setting) }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def test_connection
    source = params[:ldap_setting].present? ? "request_payload" : "stored_setting"
    config_hash = params[:ldap_setting].present? ? test_config_hash_from_params : LdapSetting.current.to_ldap_config_hash
    config = Auth::Ldap::Config.new(config_hash)

    log_ldap_test_request(source:, config_hash:)
    result = Auth::Ldap::ConnectionDiagnostic.new(config: config).call(login: params[:login], password: params[:password])
    log_ldap_test_result(source:, result:)

    render json: {
      data: {
        success: result.success?,
        auth_success: result.auth_success?,
        stage: result.stage,
        code: result.code,
        detail: sanitize_for_json(result.detail),
        hint: sanitize_for_json(result.hint),
        user_information: sanitize_for_json(result.user_information),
        ldap_attributes: sanitize_for_json(result.ldap_attributes),
        ldap_groups: sanitize_for_json(result.ldap_groups),
        search_attempts: sanitize_for_json(result.search_attempts),
        resolved_dn_candidates: sanitize_for_json(result.resolved_dn_candidates)
      }
    }, status: :ok
  end

  private

  def payload(setting)
    {
      enabled: setting.enabled,
      allow_sign_up: setting.allow_sign_up,
      fallback_to_database_auth: setting.fallback_to_database_auth,
      host: setting.host,
      port: setting.port,
      encryption: setting.encryption,
      bind_dn: setting.bind_dn,
      bind_password_present: setting.bind_password.present?,
      search_base_dn: setting.search_base_dn,
      search_filter: setting.search_filter,
      attr_username: setting.attr_username,
      attr_email: setting.attr_email,
      attr_name: setting.attr_name,
      updated_by_user_id: setting.updated_by_user_id,
      updated_at: setting.updated_at
    }
  end

  def ldap_setting_params
    attrs = params.require(:ldap_setting).permit(
      :enabled,
      :allow_sign_up,
      :fallback_to_database_auth,
      :host,
      :port,
      :encryption,
      :bind_dn,
      :bind_password,
      :search_base_dn,
      :search_filter,
      :attr_username,
      :attr_email,
      :attr_name
    )

    attrs.delete(:bind_password) if attrs[:bind_password].to_s.strip.empty?
    attrs
  end

  def test_config_hash_from_params
    persisted = LdapSetting.current
    requested_bind_dn = params.require(:ldap_setting).fetch(:bind_dn).to_s
    requested_bind_password = params.require(:ldap_setting).fetch(:bind_password).to_s

    {
      enabled: true,
      allow_sign_up: false,
      fallback_to_database_auth: true,
      servers: [
        {
          host: params.require(:ldap_setting).fetch(:host),
          port: params.require(:ldap_setting).fetch(:port),
          encryption: params.require(:ldap_setting).fetch(:encryption),
          bind_dn: requested_bind_dn.presence || persisted.bind_dn,
          bind_password: requested_bind_password.presence || persisted.bind_password,
          search_base_dns: [ params.require(:ldap_setting).fetch(:search_base_dn) ],
          search_filter: params.require(:ldap_setting).fetch(:search_filter),
          attributes: {
            username: params.require(:ldap_setting).fetch(:attr_username),
            email: params.require(:ldap_setting).fetch(:attr_email),
            name: params.require(:ldap_setting).fetch(:attr_name)
          }
        }
      ]
    }
  end

  def log_ldap_update_request
    raw = params.fetch(:ldap_setting, ActionController::Parameters.new)
                .permit(
                  :enabled,
                  :allow_sign_up,
                  :fallback_to_database_auth,
                  :host,
                  :port,
                  :encryption,
                  :bind_dn,
                  :bind_password,
                  :search_base_dn,
                  :search_filter,
                  :attr_username,
                  :attr_email,
                  :attr_name
                )
                .to_h
    Rails.logger.info(
      "[LDAP_CONFIG] update_request " \
      "#{{
        keys: raw.keys.sort,
        bind_dn_present: raw["bind_dn"].to_s.present?,
        bind_password_present: raw["bind_password"].to_s.present?,
        bind_password_length: raw["bind_password"].to_s.length,
        host: raw["host"],
        port: raw["port"],
        encryption: raw["encryption"],
        search_base_dn: raw["search_base_dn"],
        search_filter: raw["search_filter"],
        attr_username: raw["attr_username"],
        attr_email: raw["attr_email"],
        attr_name: raw["attr_name"]
      }.to_json}"
    )
  end

  def log_ldap_state(stage, setting, extra = {})
    Rails.logger.info(
      "[LDAP_CONFIG] #{stage} " \
      "#{{
        id: setting.id,
        updated_at: setting.updated_at,
        bind_dn_present: setting.bind_dn.present?,
        bind_dn_length: setting.bind_dn.to_s.length,
        bind_password_present: setting.bind_password.present?,
        bind_password_length: setting.bind_password.to_s.length,
        host: setting.host,
        port: setting.port,
        encryption: setting.encryption,
        search_base_dn: setting.search_base_dn,
        search_filter: setting.search_filter,
        attr_username: setting.attr_username,
        attr_email: setting.attr_email,
        attr_name: setting.attr_name
      }.merge(extra).to_json}"
    )
  end

  def log_ldap_test_request(source:, config_hash:)
    server = config_hash[:servers].first || {}
    Rails.logger.info(
      "[LDAP_TEST] request " \
      "#{{
        source:,
        login: params[:login].to_s,
        password_present: params[:password].to_s.present?,
        password_length: params[:password].to_s.length,
        bind_dn_present: server[:bind_dn].to_s.present?,
        bind_password_present: server[:bind_password].to_s.present?,
        bind_password_length: server[:bind_password].to_s.length,
        host: server[:host],
        port: server[:port],
        encryption: server[:encryption],
        search_base_dns: server[:search_base_dns],
        search_filter: server[:search_filter]
      }.to_json}"
    )
  end

  def log_ldap_test_result(source:, result:)
    Rails.logger.info(
      "[LDAP_TEST] result " \
      "#{{
        source:,
        success: result.success?,
        auth_success: result.auth_success?,
        stage: result.stage,
        code: result.code,
        user_dn: result.user_information&.dig(:dn),
        groups_count: result.ldap_groups.to_a.size,
        search_attempts: result.search_attempts
      }.to_json}"
    )
  end

  def require_admin_membership_or_global_admin!
    return if current_user.admin?
    return if current_membership&.role == "admin"

    render json: { error: "Insufficient permissions" }, status: :forbidden
  end

  def sanitize_for_json(value)
    case value
    when String
      value.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
    when Array
      value.map { |item| sanitize_for_json(item) }
    when Hash
      value.each_with_object({}) do |(key, v), acc|
        acc[sanitize_for_json(key.to_s)] = sanitize_for_json(v)
      end
    else
      value
    end
  end
end
