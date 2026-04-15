# Analysis Guidelines - ISP/NOC

Use esta matriz em toda analise.

## 1) Operacao ISP
Perguntas:
- Isso ajuda ou atrapalha o operador do NOC?
- O estado operacional fica claro em menos de 10 segundos?
- Em incidente, a tela mostra onde agir primeiro?
- O fluxo reduz MTTR ou apenas adiciona informacao?

Sinais de problema:
- Excesso de cliques para chegar ao ponto de falha.
- Status ambiguo ("warning" sem contexto de impacto).
- Falta de correlacao entre alerta e elemento de topologia.

## 2) Escalabilidade
Perguntas:
- Funciona com milhares de nos/cabos sem travar UX?
- Backend evita N+1 e consultas pesadas por renderizacao?
- Existe estrategia de agregacao/clustering por POP/regiao?

Sinais de problema:
- Payloads gigantes sem paginacao/filtragem.
- Mapa tenta desenhar tudo no mesmo nivel.
- Falta de degradacao graciosa (modo simplificado).

## 3) Observabilidade
Perguntas:
- Estado mostrado e "real" ou apenas decorativo?
- Existe correlacao trigger/evento -> host/item -> link/no?
- Diferencia dado live vs cache?

Sinais de problema:
- Mapa colorido sem origem de dado rastreavel.
- Eventos sem timeline ou sem severidade consistente.
- Fadiga de alertas por falta de consolidacao.

## 4) Arquitetura
Perguntas:
- O desenho atual e sustentavel para evolucao?
- Controllers estao finos e regra esta em services?
- Integracao com Zabbix esta abstraida para permitir futuro multi-fonte?

Sinais de problema:
- Acoplamento rigido com formato atual do Zabbix.
- Regra de negocio espalhada em controller/serializer.
- Sem contrato claro para front consumir estado operacional.

## 5) Adaptacao ao repositorio atual (inferencias)
- O projeto ja possui:
  - rotas V2 e legadas (`config/routes.rb`)
  - services de mapa/cabo (`app/services/network_maps/*`, `app/services/network_cables/*`)
  - eventos/metricas/health (`NetworkMapsV2Controller`)
  - integracao Zabbix com fallback e live fetch (`app/services/zabbix/live_values_fetcher.rb`)
- Gargalos provaveis:
  - coexistencia de superfice legada + V2 aumenta custo de manutencao
  - possivel heterogeneidade de envelope de resposta em controllers
  - mapa pode precisar de modo agregado para escala alta

Itens acima devem ser tratados como hipotese quando nao houver benchmark: `Precisa de validacao`.

