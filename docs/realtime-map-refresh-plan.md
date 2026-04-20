# Plano de Evolução — Atualização Quase Real-Time do Mapa

## Contexto atual (2026-04-20)

O projeto já possui base funcional para realtime:

- Canal websocket por mapa em `app/channels/map_channel.rb` (`initial` e `refresh`).
- Job de broadcast em `app/jobs/map_metrics_broadcast_job.rb`.
- Builders separados para nós/cabos/eventos:
  - `NetworkMaps::MetricsPayloadBuilder`
  - `NetworkMaps::CableMetricsPayloadBuilder`
  - `NetworkMaps::RecentEventsPayloadBuilder`
- Coleta de valores live agrupada por conexão em `Zabbix::LiveValuesFetcher`.

Hoje, o fluxo ainda é orientado por requisição explícita do cliente (`refresh`) e por jobs disparados por mutações. Falta um ciclo periódico performático e previsível por conexão/mapa, sem depender de input do usuário.

---

## Objetivo

Atualizar métricas/status/eventos no mapa em tempo quase real, de forma eficiente, resiliente e escalável.

### Meta de produto

- Atualização automática sem ação do usuário.
- Latência percebida baixa (10–30s, configurável por criticidade).
- Sem explosão de carga em banco/API Zabbix.
- Sem regressão em isolamento multi-organização.

### Não objetivo (neste ciclo)

- Streaming em sub-segundo.
- Reescrever pipeline de monitoramento inteiro.
- Introduzir dependências externas grandes sem necessidade.

---

## Princípios técnicos

1. **Pull no backend, push no frontend**.
2. **Coleta por conexão** (evitar N+1 e duplicidade por usuário).
3. **Broadcast por mapa somente quando houver mudança relevante**.
4. **Delta > snapshot completo**, sempre que possível.
5. **Degradação graciosa**: fallback para último valor conhecido.

---

## Arquitetura alvo

### 1) Scheduler recorrente

- Novo job recorrente (ex.: `MapRealtimeSchedulerJob`) roda em intervalo fixo (default 30s).
- Seleciona mapas elegíveis por `zabbix_connection` ativa.
- Usa jitter de poucos segundos para evitar rajada sincronizada.

### 2) Coleta e agregação por conexão

- Novo service (ex.: `NetworkMaps::Realtime::ConnectionCollector`) agrupa mapas por `zabbix_connection_id`.
- Coleta live values uma vez por conexão/intervalo.
- Reaproveita os builders atuais para cálculo de payload.

### 3) Detecção de mudança (change detection)

- Persistir hash/version do último payload por mapa (cache).
- Só broadcast se:
  - hash mudou, ou
  - passou janela máxima sem broadcast (keepalive controlado).

### 4) Broadcast incremental

- Mensagem websocket com `type: "broadcast"`, `version`, `generated_at`.
- Fase 1: payload completo existente.
- Fase 2: delta por seções (`metrics_delta`, `cable_metrics_delta`, `events_delta`).

### 5) Governança de frequência

- Config por ambiente:
  - `MAP_REALTIME_INTERVAL_SECONDS` (default 30)
  - `MAP_REALTIME_MIN_BROADCAST_INTERVAL_SECONDS` (default 5)
  - `MAP_REALTIME_IDLE_INTERVAL_SECONDS` (default 120)
- Quando mapa sem subscribers ativos, reduzir frequência (idle mode).

---

## Plano de execução por fases

## Fase 1 — Base recorrente e segura (1 sprint)

**Escopo**
- Criar scheduler recorrente.
- Criar pipeline por conexão/mapa reaproveitando builders atuais.
- Implementar hash/version por mapa para suppress de broadcast redundante.
- Adicionar telemetria mínima (tempo de coleta, tempo de broadcast, falhas).

**Entregáveis**
- `MapRealtimeSchedulerJob`
- `NetworkMaps::Realtime::TickService` (orquestração)
- `NetworkMaps::Realtime::SnapshotCache` (hash/version)
- Flags/envs de frequência
- Testes de serviço/jobs

**Critérios de aceite**
- Sem ação do cliente, mapa recebe updates periódicos.
- Sem alteração de payload contratual para frontend.
- Broadcast só ocorre quando payload muda (ou keepalive configurado).

## Fase 2 — Otimização de payload e carga (1 sprint)

**Escopo**
- Delta payload por seção (nós/cabos/eventos).
- Throttling por mapa.
- Idle mode baseado em subscribers.

**Entregáveis**
- `NetworkMaps::Realtime::DiffBuilder`
- Metadados `version/sequence` em mensagens.
- Ajustes no store frontend para aplicar delta.

**Critérios de aceite**
- Redução de bytes por broadcast em pelo menos 40% nos mapas grandes.
- Redução de broadcasts redundantes por mapa.

## Fase 3 — Robustez operacional (1 sprint)

**Escopo**
- Backoff em conexões com erro.
- Quarentena temporária por conexão Zabbix instável.
- Dashboards internos de observabilidade.

**Entregáveis**
- `ConnectionHealthPolicy` para intervalo dinâmico.
- Métricas e alarmes (falha por conexão, lag de atualização, idade do snapshot).

**Critérios de aceite**
- Falhas em uma conexão não degradam todo o cluster de mapas.
- Operação consegue identificar rapidamente conexão problemática.

---

## Backlog técnico (ordem sugerida)

1. Criar `NetworkMaps::Realtime::TickService` com interface única `call`.
2. Introduzir `SnapshotCache` para hash/version por mapa.
3. Refatorar `MapMetricsBroadcastJob` para reaproveitar `TickService`.
4. Implementar `MapRealtimeSchedulerJob` com intervalo por env.
5. Adicionar testes:
   - dispara broadcast quando muda,
   - não dispara quando não muda,
   - fallback em erro de coleta.
6. Adicionar métricas de runtime no log estruturado.
7. Fase 2: `DiffBuilder` + compatibilidade frontend.
8. Fase 3: políticas de backoff e health.

---

## Riscos e mitigação

- **Risco:** carga alta no Zabbix DB.
  - **Mitigação:** agrupamento por conexão, intervalo mínimo, idle mode.
- **Risco:** corrida de jobs concorrentes por mesmo mapa.
  - **Mitigação:** lock curto por mapa (cache lock) + idempotência por version.
- **Risco:** frontend receber eventos fora de ordem.
  - **Mitigação:** `version/sequence` e descarte de mensagens antigas.
- **Risco:** regressão em multi-tenant.
  - **Mitigação:** manter escopo por `network_map` e autorização existente do `MapChannel`.

---

## Métricas de sucesso

- Tempo médio de tick por conexão.
- Broadcasts/min por mapa.
- % broadcasts com mudança real.
- Tamanho médio de payload.
- Idade média da última atualização por mapa.
- Taxa de erro por conexão Zabbix.

---

## Estratégia de rollout

1. Habilitar por feature flag em `staging` para subset de mapas.
2. Validar latência/carga por 48h.
3. Produção gradual por organização (canary).
4. Ativar delta payload apenas após estabilidade da fase 1.

---

## Próxima ação recomendada

Iniciar Fase 1 implementando `NetworkMaps::Realtime::TickService` e `SnapshotCache`, mantendo o contrato websocket atual para zero impacto no frontend.
