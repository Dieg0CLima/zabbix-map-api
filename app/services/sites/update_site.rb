class Sites::UpdateSite
  def initialize(site:, params:, actor: nil)
    @site = site
    @params = params
    @actor = actor
  end

  def call
    attrs = @params.deep_dup
    attrs[:metadata] = (@site.metadata || {}).merge(attrs[:metadata] || {}).merge("updated_by_id" => @actor&.id)
    @site.update!(attrs)
    @site
  end
end
