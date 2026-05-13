module Tenancy
  class Resolver
    MODES = %w[multi single].freeze

    class << self
      def current_organization(user:, params:)
        if single_tenant_mode?
          resolve_single_tenant_organization(user: user, params: params)
        else
          resolve_multi_tenant_organization(user: user, params: params)
        end
      end

      def single_tenant_mode?
        tenancy_mode == "single"
      end

      def tenancy_mode
        mode = (ENV["TENANCY_MODE"] || "multi").to_s.strip.downcase
        MODES.include?(mode) ? mode : "multi"
      end

      private

      def resolve_multi_tenant_organization(user:, params:)
        organization_id = params[:organization_id] || params[:org_id]

        if organization_id.present?
          if user.admin?
            Organization.find_by(id: organization_id)
          else
            user.organizations.find_by(id: organization_id)
          end
        elsif user.admin?
          nil
        else
          user.current_organization
        end
      end

      def resolve_single_tenant_organization(user:, params:)
        requested_organization_id = params[:organization_id] || params[:org_id]
        if requested_organization_id.present?
          return Organization.find_by(id: requested_organization_id) if user.admin?

          scoped = user.organizations.find_by(id: requested_organization_id)
          return scoped if scoped.present?
        end

        configured = configured_single_tenant_organization
        return configured if configured.present?

        user.current_organization || Organization.order(:id).first
      end

      def configured_single_tenant_organization
        org_id = ENV["TENANCY_ORGANIZATION_ID"].to_s.strip
        return if org_id.blank?

        Organization.find_by(id: org_id)
      end
    end
  end
end
