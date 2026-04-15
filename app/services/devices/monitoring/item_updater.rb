module Devices
  module Monitoring
    class ItemUpdater
      def initialize(item:, params:)
        @item = item
        @params = params
      end

      def call
        item.update!(permitted_params)
        item
      end

      private

      attr_reader :item, :params

      def permitted_params
        params.slice(:alias, :category, :subcategory, :usage, :display_priority, :map_visibility, :is_primary_metric, :is_health_metric, :metadata)
      end
    end
  end
end
