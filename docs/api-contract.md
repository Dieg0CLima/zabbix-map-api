# API Contract — Network Map (Frontend)

Este documento descreve um contrato recomendado para o frontend consumir mapas, nós e cabos.

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

## 2) Exemplo de payload (GET /api/v1/network_maps/:id)

```json
{
  "data": {
    "id": 10,
    "name": "Datacenter - Core",
    "source_type": "hybrid",
    "coordinate_system": "screen",
    "viewport": { "width": 1920, "height": 1080, "zoom": 1.0 },
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

## 3) Estratégia no frontend (React/Vue/Canvas/SVG)

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

## 4) Boas práticas de persistência

- salvar coordenadas em decimal (já modelado) e manter precisão consistente;
- normalizar ordenação de `network_cable_points` por `position`;
- evitar cabo duplicado entre o mesmo par de nós no mesmo mapa;
- manter metadados de estilo em `metadata` para não quebrar schema.
