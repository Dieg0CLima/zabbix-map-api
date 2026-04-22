# Log de Decisoes Tecnicas

Formato recomendado:
- `YYYY-MM-DD | status | decisao | contexto | impacto | referencia`

Entradas:
- `2026-04-22 | accepted | Expor simultaneamente `pop_id` (external_id) e `map_pop_id` no payload de `editor_state` | O fluxo de snap do frontend depende de um identificador estável do POP e coexistem chamadas que aceitam id numérico ou external_id | Mantém compatibilidade retroativa, evita lookup ambíguo no front e reduz falhas de vínculo em cabos importados por KMZ/KML | app/serializers/api/v1/map_element_serializer.rb; app/services/network_cables/edit_geometry.rb`
- `2026-04-22 | accepted | Reaproveitar `PATCH /network_cables/:id/geometry` para vínculo de endpoint com POP via operação dedicada `attach_endpoint_to_pop` | O fluxo de drag-and-drop pós-importação KMZ/KML precisava reancorar extremo do cabo em POP sem exigir `PATCH` completo do recurso e sem corrida entre duas chamadas | Mantém edição incremental com `geometry_version`, reduz fricção no frontend e evita conflito de validação limpando o node legado do lado reancorado | app/services/network_cables/edit_geometry.rb; docs/api-contract.md`
- `2026-04-15 | accepted | Adotar memoria tecnica local em .llm para padronizar operacao de agentes neste repositorio | Havia somente base compartilhada em ../.llm; faltava contexto operacional local estruturado | Onboarding mais rapido e menor risco de mudancas inconsistentes | .llm/README.md`
- `2026-04-15 | accepted | Registrar incertezas explicitamente com "Precisa de validacao" | Parte das informacoes de produto/roadmap nao esta 100% dedutivel do codigo | Evita alucinacao e deixa pendencias rastreaveis | .llm/idea.md`
- `2026-04-16 | accepted | Introduzir camada derivada de estado operacional no payload realtime de cabos sem quebrar contrato atual | MVP ja entregava itens e status, mas faltava interpretacao operacional do enlace (ocupacao/capacidade/erro) | Evolucao incremental: payload atual mantido e enriquecido com campos aditivos; frontend pode adotar gradualmente | app/services/network_maps/cable_metrics_payload_builder.rb; app/services/network_cables/operational_state_builder.rb; docs/api-contract.md`
