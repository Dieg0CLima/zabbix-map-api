# Modulos Principais e Responsabilidades

## 1) Autenticacao e identidade
- Rotas Devise JWT: `config/routes.rb` (`devise_for :users`)
- Controllers: `app/controllers/api/v1/users/registrations_controller.rb`, `sessions_controller.rb`, `me_controller.rb`
- Servico de cadastro: `app/services/users/register.rb`

## 2) Organizacao e acesso
- Modelos: `app/models/organization.rb`, `membership.rb`, `user.rb`
- Contexto e autorizacao: `app/controllers/application_controller.rb`, `app/controllers/concerns/organization_scoped.rb`

## 3) Mapas de rede (V2)
- Controller principal: `app/controllers/api/v1/network_maps_v2_controller.rb`
- Services: `app/services/network_maps/*`
- Serializer: `app/serializers/api/v1/network_map_serializer.rb`
- Entidades: `network_map`, `map_node`, `map_edge`, `map_monitoring_binding`, `map_node_item`, `network_cable`

## 4) Superficie legada
- `app/controllers/api/v1/network_maps_controller.rb`
- Rotas em `config/routes.rb` sob `legacy/network_maps`
- Mantem compatibilidade de clientes antigos.

## 5) Cabos e eventos
- Controller: `app/controllers/api/v1/network_cables_controller.rb`
- Services: `app/services/network_cables/*`, `app/services/network_cable_events/*`, `app/services/network_cable_items/*`
- Modelo: `app/models/network_cable.rb`

## 6) Inventario (sites/dispositivos/interfaces)
- Controllers: `sites_controller.rb`, `devices_controller.rb`, `device_interfaces_controller.rb`
- Services: `app/services/inventory/*`, `app/services/sites/*`, `app/services/devices/*`
- Modelos: `site.rb`, `device.rb`, `device_interface.rb`

## 7) Integracao Zabbix
- Controllers: `zabbix_connections_controller.rb`, `zabbix_hosts_controller.rb`, `zabbix_items_controller.rb`, `zabbix_connection_dropdowns_controller.rb`
- Services: `app/services/zabbix/*`, `app/services/zabbix_connections/*`, `app/services/zabbix_hosts/*`, `app/services/zabbix_items/*`
- Modelos de cache: `app/models/zabbix/host.rb`, `app/models/zabbix/item.rb`

## 8) Monitoramento de mapa/dispositivo
- Device monitoring: `app/services/devices/monitoring/*`
- Health/metrics/events de mapa: `Monitoring::MapHealthFetcher`, `Zabbix::MetricsFetcher`, `Zabbix::ProblemFetcher`
- Contrato de metricas de node item: `docs/node-item-metrics-contract.md`

