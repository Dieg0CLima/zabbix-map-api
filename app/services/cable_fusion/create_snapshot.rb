module CableFusion
  class CreateSnapshot
    def initialize(diagram:, actor:, reason: nil, published: false, version: nil)
      @diagram = diagram
      @actor = actor
      @reason = reason
      @published = published
      @version = version
    end

    def call
      CableFusion::Snapshot.create!(
        diagram: @diagram,
        version: snapshot_version,
        payload: CableFusion::PayloadBuilder.new(diagram: @diagram).call,
        created_by_user: @actor,
        reason: @reason,
        published: @published
      )
    end

    private

    def snapshot_version
      return @version if @version.present?

      (@diagram.snapshots.maximum(:version) || 0) + 1
    end
  end
end
