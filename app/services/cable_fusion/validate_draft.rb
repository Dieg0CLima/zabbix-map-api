module CableFusion
  class ValidateDraft
    Result = Struct.new(:valid?, :errors, keyword_init: true)

    def initialize(diagram:)
      @diagram = diagram
    end

    def call
      errors = validators.flat_map(&:call).uniq
      Result.new(valid?: errors.empty?, errors:)
    end

    private

    def validators
      [
        CableFusion::Validators::BrokenLinksValidator.new(diagram: @diagram),
        CableFusion::Validators::PortCapacityValidator.new(diagram: @diagram),
        CableFusion::Validators::DuplicateFiberUsageValidator.new(diagram: @diagram),
        CableFusion::Validators::FiberExistenceValidator.new(diagram: @diagram)
      ]
    end
  end
end
