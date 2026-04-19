module Sites
  module Monitoring
    class ValidationError < StandardError
      attr_reader :source, :status

      def initialize(message, source:, status: :unprocessable_entity)
        super(message)
        @source = source
        @status = status
      end
    end
  end
end
