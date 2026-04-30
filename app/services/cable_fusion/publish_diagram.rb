module CableFusion
  class PublishDiagram
    def initialize(diagram:, actor:, reason: nil)
      @diagram = diagram
      @actor = actor
      @reason = reason
    end

    def call
      validation = CableFusion::ValidateDraft.new(diagram: @diagram).call
      return [ @diagram, validation ] unless validation.valid?

      ActiveRecord::Base.transaction do
        @diagram.update!(
          status: "ready",
          version: @diagram.version + 1,
          published_at: Time.current,
          published_by_user: @actor,
          last_validated_at: Time.current,
          validation_errors_count: 0
        )

        CableFusion::CreateSnapshot.new(
          diagram: @diagram,
          actor: @actor,
          reason: @reason.presence || "publish",
          published: true
        ).call
      end

      [ @diagram.reload, validation ]
    end
  end
end
