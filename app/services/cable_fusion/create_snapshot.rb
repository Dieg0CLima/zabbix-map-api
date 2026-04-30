module CableFusion
  class CreateSnapshot
    def initialize(diagram:, actor:, reason: nil, published: false)
      @diagram = diagram
      @actor = actor
      @reason = reason
      @published = published
    end

    def call
      CableFusion::Snapshot.create!(
        diagram: @diagram,
        version: @diagram.version,
        payload: CableFusion::PayloadBuilder.new(diagram: @diagram).call,
        created_by_user: @actor,
        reason: @reason,
        published: @published
      )
    end
  end
end
