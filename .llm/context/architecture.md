# Arquitetura Atual (baseada no codigo)

## Camadas praticas
- Controllers API em `app/controllers/api/v1/`:
  - orquestram parametros/autorizacao
  - delegam para services/payload builders
- Services em `app/services/`:
  - casos de uso por contexto (`network_maps/*`, `network_cables/*`, `zabbix/*`, `inventory/*`)
- Models em `app/models/`:
  - persistencia, associacoes, validacoes e invariantes locais
- Serializers/payload builders:
  - `app/serializers/api/v1/*`
  - builders em services (ex.: `network_maps/payload_builder.rb`, `network_cables/payload_builder.rb`)

## Multi-tenant e autorizacao
- `ApplicationController` resolve `current_organization` por `organization_id`/`org_id`.
- `Api::V1::BaseController` aplica `authenticate_user!` + `ensure_organization_access!`.
- `OrganizationScoped` define scopes seguros para `NetworkMap` e `ZabbixConnection`.
- Escrita protegida com `require_editor_or_admin!`.

Arquivos:
- `app/controllers/application_controller.rb`
- `app/controllers/api/v1/base_controller.rb`
- `app/controllers/concerns/organization_scoped.rb`

## Dominio de mapas/topologia
- `NetworkMap` agrega `MapPop`, `MapNode`, `MapEdge`, `NetworkCable`, `NetworkMapSnapshot`.
- `NetworkCable` possui validacoes de integridade entre mapa, pops/nos e pontos.
- `NetworkCablePoint` define polyline por `position`.

Arquivos:
- `app/models/network_map.rb`
- `app/models/network_cable.rb`
- `app/models/network_cable_point.rb`

## Integracao Zabbix
- `ZabbixConnection` controla modo `api|database|hybrid` e segredos criptografados (`api_token`, `db_password`).
- Services em `app/services/zabbix/*` tratam conexao DB/API, historico, problemas, metricas e formatacao.
- `Zabbix::LiveValuesFetcher` e regra operacional para `lastvalue/lastclock` em respostas sensiveis.

Arquivos:
- `app/models/zabbix_connection.rb`
- `app/services/zabbix/live_values_fetcher.rb`
- `app/services/zabbix/history_cache.rb`

## Observacoes de consistencia
- Nem todos os controllers usam o mesmo helper de resposta (`ApiResponse`).
- Existe convivencia de superficie legada e V2 no mesmo namespace.

## Incertezas
- `Precisa de validacao`: estrategia oficial de convergencia entre payload builders e serializers (ambos coexistem).

