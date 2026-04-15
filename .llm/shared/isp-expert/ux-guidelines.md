# UX Guidelines - Operacao NOC

## Principios
- Clareza operacional acima de estetica.
- Estado da rede compreensivel em segundos.
- Menos ruido visual, mais acao objetiva.

## Regras praticas
- Priorizar legibilidade em telas grandes (TV/videowall NOC).
- Usar cores com semantica operacional consistente:
  - vermelho: critico/down
  - amarelo: degradado/alerta
  - verde: saudavel/up
  - cinza: desconhecido/sem dados
- Evitar excesso de animacao; animacao so para indicar mudanca critica.
- Limitar densidade visual: clusterizar quando zoom-out.
- Garantir drill-down rapido (POP -> no -> interface/item/evento).
- Mostrar impacto de falha (link down afetando varios nos/servicos).

## Anti-patterns
- Mapa "bonito" sem indicar prioridade operacional.
- Card/tooltip sem severidade, timestamp e origem do dado.
- Alertas piscando sem consolidacao por causa raiz.
- Mesma cor para estados diferentes.

## Checklist de tela operacional
- [ ] Operador identifica incidente principal em <10s.
- [ ] Existem filtros por severidade, regiao/POP e tipo de ativo.
- [ ] Ha indicacao de ultimo update e fonte (live/cache).
- [ ] Ha navegacao rapida para entidade afetada.
- [ ] Ha modo simplificado para tela grande (NOC mode).

