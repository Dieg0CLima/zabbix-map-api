module Tenancy
  class Resolver
    MODES = %w[multi single].freeze

    class << self
      def current_organization(user:, params:)
        configured_single_tenant_organization || user.current_organization || Organization.order(:id).first
      end

      def single_tenant_mode?
        true
      end

      def tenancy_mode
        "single"
      end

      private

      def configured_single_tenant_organization
        org_id = ENV["TENANCY_ORGANIZATION_ID"].to_s.strip
        return if org_id.blank?

        Organization.find_by(id: org_id)
      end
    end
  end
end
