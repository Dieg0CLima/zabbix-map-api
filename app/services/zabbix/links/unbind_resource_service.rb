class Zabbix::Links::UnbindResourceService
  def initialize(zabbix_link:)
    @zabbix_link = zabbix_link
  end

  def call
    @zabbix_link.destroy!
  end
end
