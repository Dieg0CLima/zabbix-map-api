class NetworkCables::Errors::DomainError < StandardError
  attr_reader :details

  def initialize(message: "Payload inválido", details: {})
    @details = details
    super(message)
  end
end
