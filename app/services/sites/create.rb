module Sites
  class Create
    def initialize(organization:, payload:)
      @organization = organization
      @payload = payload
    end

    def call
      site = @organization.sites.new(@payload)
      site.save!
      site
    end
  end
end
