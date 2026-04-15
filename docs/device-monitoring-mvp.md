# Device Monitoring MVP

## Objetivo imediato
- garantir que o registro de um `Device` reflita claramente o `Host` correspondente no Zabbix;
- permitir que o frontend obtenha um catálogo leve dos itens disponíveis sem puxar telemetria;
- persistir a seleção funcional de itens (mapa, indicadores, observabilidade, health) com categorias simples;
- preparar a base para filtros ISP (CPU, tráfego, disponibilidade) e caçar performance.

## Design de domínio
- **DeviceMonitoringProfile** (1:1 com `Device`): replica o vínculo técnico (conexão, hostid, metadata) e guarda `synced_at` para saber quando atualizar o catálogo;
- **DeviceMonitoringItem**: referências `DeviceMonitoringProfile` + `Zabbix::Item`, guarda alias, categoria, prioridade e flags operacionais (`map_visibility`, `is_primary_metric`, `is_health_metric`);
- `Zabbix::Item` segue sendo o catálogo cacheado (`zabbix_items`), sincronizado via `ZabbixHosts::ItemsFetcher` e reusado na seleção do device;
- `ZabbixLink` permanece como o vínculo genérico; o novo profile o observa para compor a view operacional.

## Fluxo de dados MVP
1. O cadastro/edição do device continua chamando `Devices::ZabbixHostLinkUpserter`.
2. Logo após, um novo `Devices::MonitoringProfileSync` garante que o `DeviceMonitoringProfile` existe e reflete o `zabbix_host_link` atual; quando o host for removido, o profile é destruído.
3. O frontend chama `GET /api/v1/devices/:id/monitoring/available-items` para obter o catálogo (sem telemetria).
4. Para salvar um item, o frontend POSTa em `/devices/:id/monitoring/items` informando `zabbix_item_id`, categoria, uso e alias; o backend cria `DeviceMonitoringItem` e aplica heurísticas simples de categoria via `key`/`units`.
5. A listagem `/monitoring/items` separa claramente itens escolhidos (metadados + flags), enquanto `/monitoring/summary` agrega os principais indicadores por categoria usando `is_primary_metric` e `is_health_metric`.

## API MVP proposta
- `PUT /api/v1/devices/:id/monitoring/host-link` → cria/atualiza profile (aproveitando `Devices::MonitoringProfileSync`).
- `GET /api/v1/devices/:id/monitoring/available-items` → retorna atributos leves de `Zabbix::Item` + `category_hint`, `suggested_alias`.
- `POST /api/v1/devices/:id/monitoring/items` → cria seleção funcional (alias, category, usage, map_visibility).
- `GET /api/v1/devices/:id/monitoring/items` → lista itens monitorados com classification e status.
- `PATCH /api/v1/devices/:id/monitoring/items/:id` → atualiza alias, uso, prioridade, flags.
- `DELETE /api/v1/devices/:id/monitoring/items/:id` → remove item monitorado.
- `GET /api/v1/devices/:id/monitoring/summary` → resume CPU/Mem/Disponibilidade com base nos itens `is_primary_metric` + `is_health_metric`.

### Exemplos de respostas imediatas
- `PUT /devices/:id/monitoring/host-link` retorna o profile com `zabbix_connection_id`, `zabbix_hostid`, `host_label` e `metadata` indicando `synced_at`.
- `GET /devices/:id/monitoring/available-items` retorna `item_id`, `label`, `key`, `units`, `category_hint`, `map_visibility` sugerida e `metadata` básico (sem history).
- `GET /devices/:id/monitoring/items` retorna cada seleção com `category`, `usage`, `map_visibility`, `is_primary_metric`, `is_health_metric`, `display_priority` e dados do `zabbix_item` (lastvalue/lastclock).
- `GET /devices/:id/monitoring/summary` replica `category` + `usage` + `last_value` + `units` para os itens marcados como métricas principais/health.

## Classificação MVP
- Heurística de fila rápida baseada em `key_`, `name` e `units` (ex: `system.cpu` → `cpu`, `vm.memory` → `memory`, `net.if.in`/`out` → `interface_traffic_*`).
- `DeviceMonitoringItem` persiste `category`, `usage` e `display_priority`; o frontend recebe `map_visibility`, `is_primary_metric`, `is_health_metric`.
- Futuras estruturas (categoria/subcategoria, `MonitoredItemCategory`, regras baseadas em regex, tags e fabricantes) podem ser incorporadas sobre essa fundação.

## MVP entrega 1.0
1. Criar migrations para `device_monitoring_profiles` e `device_monitoring_items` + modelos com validações básicas.
2. Implementar `Devices::MonitoringProfileSync` e integrá-lo a `Devices::CreateDevice`/`Devices::UpdateDevice` após o link com o host.
3. Novo namespace `/devices/:id/monitoring` com controladores finos/serializers e services que retornam catálogo leve e seleção persistida.
4. Heurísticas simples em `DeviceMonitoringItem` (por exemplo, `category_hint` calculado em `before_validation`).
5. Documentar contratos e fluxos neste arquivo para orientar desenvolvimento incremental (próxima etapa: summary e classificações expandido).

## Próximos passos
1. Criar testes de serviços (profile sync, catalog fetcher) e specs de request para endpoints `monitoring/*`.
2. Adicionar job assíncrono de sync parcial do catálogo caso o `Devices::MonitoringProfile` indique `synced_at` antigo.
3. Registrar classification rules/MonitoredItemCategory para enriquecer o `category_hint` e permitir `usage` predefinido.

> Observação: este documento vive em `docs/` e deve ser atualizado antes de expandir do MVP para a fase escalável descrita no AGENTS.md.
