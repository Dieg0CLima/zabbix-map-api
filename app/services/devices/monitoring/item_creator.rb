module Devices
  module Monitoring
    class ItemCreator
      def initialize(profile:, params:)
        @profile = profile
        @params = params
      end

      def call
        ensure_profile!
        profile.device_monitoring_items.create!(permitted_params)
      end

      private

      attr_reader :profile, :params

      def ensure_profile!
        raise ActiveRecord::RecordNotFound, "Monitoring profile missing" unless profile&.linked?
      end

      def permitted_params
        params.slice(:zabbix_item_id, :alias, :category, :subcategory, :usage, :display_priority, :map_visibility, :is_primary_metric, :is_health_metric, :metadata)
              .merge(usage: params[:usage].presence || "map")
      end
    end
  end
end
