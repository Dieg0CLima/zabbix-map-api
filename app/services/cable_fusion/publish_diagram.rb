module CableFusion
  class PublishDiagram
    def initialize(diagram:, actor:, reason: nil)
      @diagram = diagram
      @actor = actor
      @reason = reason
    end

    def call
      draft_validation = CableFusion::ValidateDraft.new(diagram: @diagram).call
      readiness_errors = CableFusion::Validators::PublishReadinessValidator.new(diagram: @diagram).call
      errors = (draft_validation.errors + readiness_errors).uniq
      validation = CableFusion::ValidateDraft::Result.new(valid?: errors.empty?, errors:)
      return [ @diagram, validation ] unless validation.valid?
      return [ @diagram, validation ] if already_published_current_structure?

      ActiveRecord::Base.transaction do
        @diagram.update!(
          status: "ready",
          version: @diagram.version + 1,
          published_at: Time.current,
          published_by_user: @actor,
          last_validated_at: Time.current,
          validation_errors_count: 0,
          metadata: @diagram.metadata.to_h.merge("published_checksum" => @diagram.structure_checksum)
        )

        CableFusion::CreateSnapshot.new(
          diagram: @diagram,
          actor: @actor,
          reason: @reason.presence || "publish",
          published: true,
          version: @diagram.version
        ).call
      end

      [ @diagram.reload, validation ]
    end

    private

    def already_published_current_structure?
      @diagram.status == "ready" &&
        @diagram.structure_checksum.present? &&
        @diagram.metadata.to_h["published_checksum"] == @diagram.structure_checksum
    end
  end
end
