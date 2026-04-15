# Node Item Metrics Contract

## Objetivo
Permitir ao frontend consultar rapidamente o valor mais recente dos itens do Zabbix já vinculados a um nó do mapa, para que o painel possa renderizar KPIs como `Bits Received`, status de porta ou latência assim que o usuário abre o site/nó.

## Rota

```
GET /api/v1/network_maps/:network_map_id/nodes/:node_id/node_items/metrics
```

### Autorização
- Deve ser chamada com header `Authorization: Bearer <token>` emitido no login.
- O usuário precisa ter acesso à organização e, idealmente, permissão de leitura para o mapa (reutiliza os filtros atuais de `Api::V1::BaseController`).

### Parâmetros
- `network_map_id` e `node_id`: path params que identificam o mapa e o nó cuja lista de itens já está vinculada.
- Nenhum body é necessário.

### Resposta

```json
{
  "data": [
    {
      "map_node_item_id": 42,
      "map_node_external_id": "node-1",
      "map_node_id": 7,
      "alias": "Bits Received",
      "display_order": 1,
      "itemid": "30001",
      "name": "ifInOctets",
      "key": "net.if.in[1]",
      "units": "bps",
      "value_type": "3",
      "hostid": "10001",
      "status": "0",
      "state": "0",
      "lastvalue": "987654",
      "lastclock": "1800000000",
      "lastclock_iso": "2027-08-09T21:20:00Z",
      "display_value": "987654 bps",
      "data_source": "live"
    }
  ]
}
```

Campo-chave:

- `lastvalue`/`lastclock`: preferem valores ao vivo vindos do `history_uint` do Zabbix. Quando não há acesso ao banco, caem na cache (`zabbix_items.lastvalue`).
- `data_source`: `live` indica que houve consulta direta ao banco do Zabbix; `cache` significa que usamos os dados persistidos.
- `display_value`: montagem simples `"<lastvalue> <units>"` para renderizar badges.

### Comportamento esperado
- Retorna lista vazia se o nó não tiver `map_node_items` ou não houver `zabbix_item` associado (sem erro).
- Usa `Zabbix::HistoryCache` (que delega ao `HistoryFetcher`) para recuperar o registro mais recente por `itemid` quando a conexão permite leitura direta (`db_enabled?`) e reduzir consultas repetidas.
- Quando nenhum `history` está disponível, entrega os campos `lastvalue`/`lastclock` já preenchidos no banco local (`zabbix_items`).

### Sugestão de uso no frontend
1. Ao abrir o mapa e selecionar um site ou dispositivo, já carregue os nodes via `/api/v1/network_maps/:id/nodes` (ou o builder existente). Cada nó contém `external_id` e `zabbix_host`.
2. Para cada nó com `map_node_items`, dispare esta rota para obter os valores métricos associados.
3. Use `data_source` para indicar ao usuário se os dados são finais (`cache`) ou em tempo real (`live`).
4. Renderize `display_value`/`lastclock_iso` nos cards de interface/tráfego.
