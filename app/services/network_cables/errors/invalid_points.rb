class NetworkCables::Errors::InvalidPoints < NetworkCables::Errors::DomainError
  def initialize
    super(message: "Payload inválido", details: { points: ["É necessário ao menos 2 pontos"] })
  end
end
