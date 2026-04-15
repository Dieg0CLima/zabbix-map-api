# Fluxos de Dados Relevantes

## Fluxo A - Requisicao autenticada com escopo de organizacao
1. Cliente envia JWT.
2. `authenticate_user!` valida sessao (`Api::V1::BaseController` ou controller equivalente).
3. `current_organization` e resolvida por params ou membership (`app/controllers/application_controller.rb`).
4. Controller usa scope (`current_organization.network_maps` ou `scoped_*`).
5. Resposta retorna payload (serializer/payload builder).

## Fluxo B - Leitura de mapa V2
1. `GET /api/v1/network_maps/:id` em `NetworkMapsV2Controller#show`.
2. Busca mapa no escopo da organizacao.
3. `Api::V1::NetworkMapSerializer` formata resposta base.
4. Rotas relacionadas (`editor_state`, `metrics`, `events`) delegam para services especificos.

Arquivos:
- `app/controllers/api/v1/network_maps_v2_controller.rb`
- `app/serializers/api/v1/network_map_serializer.rb`
- `app/services/network_maps/*`

## Fluxo C - CRUD de cabos
1. Controller recebe payload de cabo/pontos.
2. Service (`NetworkCables::Create/Update`) aplica validacoes de dominio.
3. Persistencia em `network_cables` + `network_cable_points`.
4. `NetworkCables::PayloadBuilder` retorna estrutura ordenada de pontos.

Arquivos:
- `app/controllers/api/v1/network_cables_controller.rb`
- `app/services/network_cables/create.rb`
- `app/services/network_cables/update.rb`
- `app/services/network_cables/payload_builder.rb`

## Fluxo D - Itens Zabbix (cache + database)
1. `GET /api/v1/zabbix_connections/:id/zabbix_items`.
2. `ZabbixItems::SummaryFetcher` decide fonte conforme modo da conexao.
3. Quando DB disponivel, services de `app/services/zabbix/database_*`/`history_*` consultam fonte externa.
4. Sem DB, fallback para cache local (`zabbix_items`).

Arquivos:
- `app/controllers/api/v1/zabbix_items_controller.rb`
- `app/services/zabbix_items/summary_fetcher.rb`
- `app/services/zabbix/database_items_fetcher.rb`

## Fluxo E - Valores live (lastvalue/lastclock)
1. Coleta de `Zabbix::Item` do contexto (cabos, nodes, dashboards).
2. `Zabbix::LiveValuesFetcher` agrupa por `zabbix_connection_id`.
3. `HistoryCache` consulta por conexao (evita N+1).
4. Caller usa fallback para colunas locais.

Arquivos:
- `app/services/zabbix/live_values_fetcher.rb`
- `app/services/network_maps/cable_metrics_payload_builder.rb`
- `app/services/network_cable_items/payload_builder.rb`

