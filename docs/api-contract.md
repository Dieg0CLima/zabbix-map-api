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
- `DELETE /api/v1/network_maps/:network_map_id/network_cables/:id`

### Conexões Zabbix

- `GET /api/v1/zabbix_connections`
- `GET /api/v1/zabbix_connections/:id`
- `POST /api/v1/zabbix_connections`
- `PATCH /api/v1/zabbix_connections/:id`
- `DELETE /api/v1/zabbix_connections/:id`

### Dados sincronizados do Zabbix

- `GET /api/v1/zabbix_connections/:zabbix_connection_id/zabbix_hosts`
- `GET /api/v1/zabbix_connections/:zabbix_connection_id/zabbix_items`

`zabbix_items` aceita filtro opcional: `?zabbix_host_id=<id>`.

---

## 3) Exemplo de payload (GET /api/v1/network_maps/:id)

```json
{
  "data": {
    "id": 10,
    "name": "Datacenter - Core",
    "source_type": "hybrid",
    "nodes": [
      { "id": 101, "label": "SW-Core-01", "node_kind": "switch", "x": 300.0, "y": 220.0 },
      { "id": 102, "label": "FW-Edge-01", "node_kind": "firewall", "x": 760.0, "y": 210.0 }
    ],
    "cables": [
      {
        "id": 501,
        "label": "Uplink 10G",
        "cable_type": "fiber",
        "status": "up",
        "source_node_id": 101,
        "target_node_id": 102,
        "bandwidth_mbps": 10000,
        "points": [
          { "position": 0, "x": 470.0, "y": 170.0 },
          { "position": 1, "x": 620.0, "y": 170.0 }
        ]
      }
    ]
  }
}
```

---

## 4) Estratégia no frontend (React/Vue/Canvas/SVG)

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

## 5) Boas práticas de persistência

- salvar coordenadas em decimal (já modelado) e manter precisão consistente;
- normalizar ordenação de `network_cable_points` por `position`;
- evitar cabo duplicado entre o mesmo par de nós no mesmo mapa;
- manter metadados de estilo em `metadata` para não quebrar schema.
