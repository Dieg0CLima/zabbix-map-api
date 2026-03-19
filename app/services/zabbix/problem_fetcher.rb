class Zabbix::ProblemFetcher
  def initialize(network_map:)
    @network_map = network_map
  end

  def call
    []
  end
end
