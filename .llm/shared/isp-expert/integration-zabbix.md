# Integracao Zabbix - Diretrizes

## Objetivo
Usar dados reais de monitoramento mantendo desacoplamento suficiente para evoluir para multi-fonte no futuro.

## O que considerar sempre
- Entidades base:
  - Host
  - Item
  - Trigger/Problema
  - Historico (ultimo valor, clock, severidade)
- Latencia de sincronizacao e frequencia de update.
- Diferenca entre dado live e dado em cache.

## Mapeamento para elementos visuais
- Host -> no/dispositivo no mapa.
- Item de interface -> metrica de link/cabo.
- Trigger/problema -> estado visual (severidade, impacto, prioridade).
- Dependencia/logica de topologia -> propagacao de impacto.

## Boas praticas
- Definir camada de abstracao interna para dados de monitoramento (DTOs/servicos).
- Evitar espalhar campos especificos de Zabbix em toda API publica.
- Incluir metadados de origem e timestamp nos payloads.
- Preservar fallback seguro quando fonte live falhar.

## No repositorio atual
- Ja existe suporte `api|database|hybrid` em `ZabbixConnection`.
- Ja existe fetch de valores live em `app/services/zabbix/live_values_fetcher.rb`.
- Ja existem endpoints de itens/historico em `zabbix_items`.

## Riscos comuns
- Acoplamento rigido ao schema atual do Zabbix.
- Falta de controle de volume em leituras de historico.
- Divergencia entre estado do mapa e estado real por cache stale.

## Validacoes recomendadas
- Testar cenarios com Zabbix indisponivel.
- Medir tempo de resposta em mapas grandes.
- Validar consistencia de severidade/status entre trigger e cor no mapa.

