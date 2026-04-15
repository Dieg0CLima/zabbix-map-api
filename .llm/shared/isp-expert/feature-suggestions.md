# Feature Suggestions - ISP Focus

Sempre apresentar sugestoes com:
- Problema real resolvido
- Impacto para operacao ISP
- Complexidade (Baixa/Media/Alta)
- Prioridade (P0/P1/P2)

## Backlog base recomendado

### 1) Mapa dinamico orientado a eventos Zabbix
- Problema: mapa estatico nao reflete incidentes em tempo util.
- Impacto: reduz tempo de triagem.
- Complexidade: Media
- Prioridade: P0

### 2) Agrupamento automatico por regiao/POP
- Problema: mapa poluido em escala alta.
- Impacto: melhora leitura macro e navegacao.
- Complexidade: Media
- Prioridade: P0

### 3) Visualizacao de dependencias (upstream/downstream)
- Problema: dificil entender impacto de falha de um link.
- Impacto: acelera RCA inicial e comunicacao de impacto.
- Complexidade: Alta
- Prioridade: P0

### 4) Deteccao de falha em cascata
- Problema: NOC recebe avalanche de alertas sem causa raiz.
- Impacto: reduz fadiga e prioriza acao correta.
- Complexidade: Alta
- Prioridade: P0

### 5) Modo NOC (tela simplificada para videowall)
- Problema: interfaces detalhadas demais em tela grande.
- Impacto: leitura imediata do estado global.
- Complexidade: Baixa/Media
- Prioridade: P1

### 6) Historico de eventos no mapa (timeline)
- Problema: contexto de incidente se perde rapido.
- Impacto: facilita analise pos-incidente.
- Complexidade: Media
- Prioridade: P1

### 7) Replay de incidentes
- Problema: dificil treinar e revisar resposta operacional.
- Impacto: melhora aprendizado do NOC.
- Complexidade: Alta
- Prioridade: P2

### 8) Alertas visuais inteligentes (noise reduction)
- Problema: alto ruido de trigger.
- Impacto: foco em alarmes acionaveis.
- Complexidade: Media/Alta
- Prioridade: P0

## Adaptacao ao repositorio atual (pistas)
- Reaproveitar endpoints `health`, `metrics`, `events` em `network_maps`.
- Usar `NetworkMaps::CableMetricsPayloadBuilder` para status de links.
- Para real-time consistente, reforcar uso de `Zabbix::LiveValuesFetcher`.
- Coexistencia de legado e V2 exige feature flags ou rollout gradual.

Se nao houver metrica de volume (nos/cabos/eventos por mapa): `Precisa de validacao`.

