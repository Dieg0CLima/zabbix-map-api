# API Contract — Network Map (Frontend)

Este documento descreve um contrato recomendado para o frontend consumir mapas, nós, cabos e conexões Zabbix.

## 0) Segurança (padrão Devise + JWT)

Todos os endpoints de negócio em `/api/v1` exigem autenticação via Devise/JWT:

- `POST /api/v1/users/sign_in` para login (retorna `Authorization: Bearer <token>`).
- `DELETE /api/v1/users/sign_out` para logout.
- `POST /api/v1/users` para cadastro.
- enviar sempre `Authorization: Bearer <token>` nas chamadas autenticadas.

Além da autenticação, as operações de escrita (`create/update/destroy`) exigem papel de `admin` ou `editor` na organização do usuário.

Também existe suporte a **admin global** (`users.admin = true`), que pode operar sem vínculo de membership e atuar em qualquer organização ao informar `organization_id` na requisição.

---

## 1) Conceito de renderização

- `network_map`: contexto do mapa/canvas.
- `map_nodes`: elementos visuais (equipamentos, textos, ícones).
- `network_cables`: linhas entre nós.
- `network_cable_points`: pontos intermediários (polyline) para curvas/quebras.

No frontend, cada cabo é renderizado assim:

1. começa no centro/anchor do `source_node`;
2. passa por `network_cable_points` ordenados por `position`;
3. termina no centro/anchor do `target_node`.

---

## 2) Endpoints principais

### Mapas

- `GET /api/v1/network_maps`
- `GET /api/v1/network_maps/:id`
- `POST /api/v1/network_maps`
- `PATCH /api/v1/network_maps/:id`
- `DELETE /api/v1/network_maps/:id`

### Nós (por mapa)

- `GET /api/v1/network_maps/:network_map_id/map_nodes`
- `GET /api/v1/network_maps/:network_map_id/map_nodes/:id`
- `POST /api/v1/network_maps/:network_map_id/map_nodes`
- `PATCH /api/v1/network_maps/:network_map_id/map_nodes/:id`
- `DELETE /api/v1/network_maps/:network_map_id/map_nodes/:id`

### Cabos (por mapa)

- `GET /api/v1/network_maps/:network_map_id/network_cables`
- `GET /api/v1/network_maps/:network_map_id/network_cables/:id`
- `POST /api/v1/network_maps/:network_map_id/network_cables`
- `PATCH /api/v1/network_maps/:network_map_id/network_cables/:id`
- `PATCH /api/v1/network_maps/:network_map_id/network_cables/:id/geometry`
- `DELETE /api/v1/network_maps/:network_map_id/network_cables/:id`

`PATCH .../geometry` aplica operações incrementais de edição de rota, sem sobrescrever todo o recurso de cabo:

- `operation: "move_point"` requer `position` e `point` (`lat/lng` ou `x/y`).
- `operation: "remove_segment"` requer `from_position` e `to_position`.
- `operation: "insert_point"` requer `after_position` e `points`.
- `operation: "remove_point"` requer `position`.
- `operation: "replace_all"` requer `points`.

Opcionalmente, envie `geometry_version` para controle de concorrência otimista. Em caso de conflito, a API retorna `409` com código `geometry_conflict` e os campos `expected_version` e `current_version`.

### Conexões Zabbix

- `GET /api/v1/zabbix_connections`
- `GET /api/v1/zabbix_connections/:id`
- `POST /api/v1/zabbix_connections`
- `PATCH /api/v1/zabbix_connections/:id`
- `DELETE /api/v1/zabbix_connections/:id`

### Dados sincronizados do Zabbix

- `GET /api/v1/zabbix_connections/:zabbix_connection_id/zabbix_hosts`
- `GET /api/v1/zabbix_connections/:zabbix_connection_id/zabbix_items`
- `GET /api/v1/zabbix_connections/:zabbix_connection_id/zabbix_hosts/:id/items`

`zabbix_hosts` aceita parâmetro opcional `?limit=<n>` no modo de leitura direta no banco.

`zabbix_items` aceita filtros opcionais: `?zabbix_host_id=<id>` (cache local), `?hostid=<id>` e `?limit=<n>` (leitura direta no banco).

`zabbix_hosts/:id/items` compartilha o mesmo formato do endpoint genérico de itens e sempre contabiliza o host solicitado; o `meta` informa `connection_id`, `hostid`, `zabbix_host_id`, `limit`, `count` e `source` (`database` quando o `ZabbixConnection` consegue ler o banco diretamente, caso contrário `cache`).

Além dos mesmos filtros de `zabbix_items`, também existe o endpoint `GET /api/v1/zabbix_connections/:zabbix_connection_id/zabbix_items/history?itemid[]=...` que retorna apenas os valores mais recentes (`history`) dos `itemid`s explicitados. O contrato dessa rota é `{ "data": [history_entry,...], "meta": { "connection_id": ..., "count": ..., "source": ... } }` e os itens trazem `clock`, `ns`, `value`, `clock_iso`, `display_value`, `lastvalue`, `lastclock` e `lastns`. O frontend deve chamá-la somente para os “itens selecionados” (lista reduzida) para evitar leituras pesadas sobre as tabelas `history`/`history_uint`.

Ambos `zabbix_items` e `zabbix_hosts/:id/items` retornam um envelope `{ "data": [ ... ], "meta": { ... } }` onde cada item do array inclui:
```json
{
  "itemid": "30001",
  "name": "ifInOctets",
  "key": "net.if.in[1]",
  "value_type": "3",
  "units": "bps",
  "status": "0",
  "state": null,
  "metadata": { ... },
  "host": { "hostid": "10634", "name": "SWCX-001-001-005-CENTRAL" },
  "lastvalue": "0",
  "lastclock": "1719999999",
  "history": {
    "itemid": "30001",
    "clock": "1719999999",
    "ns": "0",
    "value": "0",
    "clock_iso": "2024-04-05T18:26:39Z",
    "units": "bps",
    "value_type": "3",
    "display_value": "0 bps"
  }
}
```

- `lastvalue`/`lastclock`: refletem o último dado armazenado (cache) ou no histórico (Database) para o item consultado.
- `history`: opcional quando o Zabbix oferece acesso ao banco; os campos `clock`, `ns`, `value`, `clock_iso` e `display_value` ajudam o frontend a renderizar métricas e aplicar formatação específica para throughput (`bps`) e uptime.
- `metadata`: replica qualquer informação extra salva no cache local para uso da UI (ex: `SNMPINDEX`, `item.transport`).

Quando nenhuma conexão consegue acessar o banco, o histórico é omitido, e o backend retorna apenas o que estiver disponível no cache `zabbix_items`. O front deve manter a mesma estrutura e confiar no `meta.source` para diferenciar entre leitura de banco (`database`) e cache (`cache`).

---

## 3) Exemplo de payload (GET /api/v1/network_maps/:id)

O payload continua retornando `pops`, `nodes` e `cables`, mas agora com:

- **layers**: descrição e agrupamento pré-definido (`pops`, `nodes`, `cables`) para permitir renderizar camadas com ordem, labels e metadata associada.
- **filters**: coleções derivadas dos metadados (PoP, tipos de nós, status Zabbix, tags, tipos de cabo) além de ações sugeridas para o frontend.
- **nodes/cables enriquecidos**: cada nó traz `zabbix_ref`, `zabbix_status`, `zabbix_host`, `zabbix_host_tags`, `actions`, coordenadas, ícones e metadata; cabos entregam `status`, `zabbix_status`, `points` completos e indicação da camada.
- **zabbix_context**: conexão, métricas, problemas (eventos), dados de sincronização e URLs/templates para abrir hosts no Zabbix.

```json
{
  "data": {
    "id": 10,
    "name": "Datacenter - Core",
    "source_type": "hybrid",
    "layers": {
      "nodes": {
        "label": "Nós",
        "order": 2,
        "data": [
          {
            "id": "node-101",
            "label": "SW-Core-01",
            "node_kind": "switch",
            "x": 300.0,
            "y": 220.0,
            "lat": -23.55,
            "lng": -46.63,
            "icon": "switch",
            "color": "#0b5d9b",
            "metadata": {
              "tier": "core",
              "floor": 2,
              "layer": "map-nodes"
            },
            "zabbix_ref": "10084",
            "zabbix_status": "up",
            "zabbix_host": {
              "hostid": "10084",
              "status": "enabled",
              "interfaces": [
                { "ip": "10.1.0.5", "type": "agent", "main": true }
              ],
              "inventory": { "vendor": "Juniper", "model": "MX480" },
              "suggested_device_attributes": { "hostname": "edge-fw-01" }
            },
            "actions": [
              {
                "type": "open_zabbix_host",
                "label": "Abrir host no Zabbix",
                "template": "https://zabbix.example/zabbix.php?action=host.detail&hostid=%{hostid}"
              }
            ]
          }
        ]
      },
      "cables": {
        "label": "Cabos",
        "order": 3,
        "data": [
          {
            "id": "cable-501",
            "label": "Uplink 10G",
            "cable_type": "fiber",
            "status": "up",
            "zabbix_status": "up",
            "points": [
              { "position": 0, "x": 470.0, "y": 170.0 },
              { "position": 1, "x": 620.0, "y": 170.0 }
            ],
            "metadata": {
              "owner": "infra",
              "path": "duct-core",
              "criticality": "high"
            }
          }
        ]
      }
    },
    "filters": {
      "node_kinds": ["switch", "firewall"],
      "node_statuses": ["up"],
      "cable_types": ["fiber"],
      "actions": [
        {
          "type": "sync_connection",
          "endpoint": "/api/v1/zabbix_connections/7"
        }
      ]
    },
    "zabbix_context": {
      "connection": {
        "id": 7,
        "name": "Zabbix EU",
        "connection_mode": "hybrid",
        "last_synced_at": "2026-03-26T07:45:00Z",
        "status": "active"
      },
      "hosts": [
        {
          "hostid": "10084",
          "status": "enabled",
          "availability": true,
          "interfaces": [
            { "ip": "10.1.0.5", "type": "agent", "main": true }
          ],
          "items_summary": [
            { "itemid": "30001", "lastvalue": "0.15", "lastclock": "2026-03-26T07:43:00Z" }
          ]
        }
      ],
      "metrics": [
        { "map_node_id": 101, "bindings_count": 2 }
      ],
      "sync": {
        "last_synced_at": "2026-03-26T07:45:00Z",
        "hosts_count": 1
      },
      "urls": {
        "host_detail": "/api/v1/zabbix_connections/7/zabbix_hosts/%{hostid}"
      }
    }
  }
}
```

## 4) Devices e dashboard vinculados

### Endpoints expostos

- `GET /api/v1/devices` lista dispositivos com dados de inventário e link para Zabbix.
- `GET /api/v1/devices/:id` retorna o registro completo de um dispositivo, interfaces coletadas do host vinculado e itens disponíveis.
- `GET /api/v1/devices/:id/dashboard` resume o host do Zabbix e os itens vinculados à interface, incluindo os últimos valores coletados direto de `history_uint`.

### `GET /api/v1/devices/:id`

```json
{
  "data": {
    "id": 5,
    "name": "SWCX-001-001-005-CENTRAL",
    "hostname": "SWCX-001-001-005-CENTRAL",
    "role": "switch",
    "management_ip": "10.1.1.5",
    "status": "active",
    "zabbix_connection_id": 3,
    "zabbix_host_id": "10634",
    "zabbix_host": {"hostid": "10634", "label": "SWCX-001-001-005-CENTRAL"},
    "zabbix_interfaces": [
      {"ip": "10.1.1.5", "dns": "", "type": "snmp", "main": true}
    ],
    "zabbix_items": [
      {"value": "30001", "label": "ifOperStatus", "itemid": "30001", "key": "net.if.oper[1]"}
    ]
  }
}
```

- `zabbix_interfaces` replica o `metadata.interfaces` trazido pelo link do host salvo em `zabbix_links`.
- `zabbix_items` traz até 100 itens (por `Zabbix::ItemFinder`) com `label`, `key`, `itemid` e `value` (itemid por compatibilidade).

### `GET /api/v1/devices/:id/dashboard`

```json
{
  "data": {
    "host": {"hostid": "10634", "name": "SWCX-001-001-005-CENTRAL", "status": "enabled", "available": true},
    "items": [
      {
        "itemid": "30001",
        "name": "ifInOctets",
        "key": "net.if.in[1]",
        "value_type": "3",
        "units": "bps",
        "status": "0",
        "state": null,
        "lastvalue": "0",
        "lastclock": "1719999999",
        "metadata": {},
        "history": {"clock": "1719999999", "value": "0", "ns": "0"}
      }
    ],
    "interface_items": [
      {
        "itemid": "30001",
        "key": "net.if.in[1]"
      }
    ]
  }
}
```

- `items` lista todos os itens recuperados do host (direto do banco do Zabbix ou cache local) com atributos extras (`value_type`, `state`, `metadata`).
- Para cada `item`, o `history` contém o último `clock`, `ns` e `value` vindos de `history_uint`, e `lastvalue`/`lastclock` seguem essa mesma leitura.
- Cada `history` agora inclui `display_value`, `value_type`, `units` e `clock_iso` (ISO 8601) para que o frontend saiba como renderizar o número/string com unidade e hora legível esport.
- Métricas de largura de banda (`bps`) recebem um `display_value` com escala SI (`Kbps`, `Mbps`, `Gbps`, etc.), e `system.uptime` é convertida em `Xd Yh Zm Ws` para facilitar a leitura.
- Para throughput, geramos valores arredondados com até duas casas decimais (`6.15 Gbps`) e removemos zeros desnecessários, enquanto unidades não numéricas permanecem como estão.
- `interface_items` é um subconjunto filtrado por chaves como `net.if` ou metadata com `SNMPINDEX`, útil para renderizar dashboards de interfaces.
- Quando a conexão com o Zabbix não está ativa (sem `db_enabled?`), a rota retorna `{"host": null, "items": [], "interface_items": []}` para o frontend lidar com ausência de dados.

---

## 5) Estratégia no frontend (React/Vue/Canvas/SVG)

### SVG (recomendado para MVP)

- montar um array de pontos do cabo:
  - `[source_anchor, ...points, target_anchor]`
- gerar `polyline` com `stroke` conforme `status`:
  - `up`: verde
  - `down`: vermelho
  - `degraded`: amarelo
  - `unknown`: cinza

### Canvas/WebGL (escala maior)

- pré-processar cabos para buffers de linha;
- re-renderizar apenas elementos alterados (dirty rectangles/layers);
- usar spatial index para hit-test e seleção rápida.

---

## 6) Boas práticas de persistência

- salvar coordenadas em decimal (já modelado) e manter precisão consistente;
- normalizar ordenação de `network_cable_points` por `position`;
- evitar cabo duplicado entre o mesmo par de nós no mesmo mapa;
- manter metadados de estilo em `metadata` para não quebrar schema.
