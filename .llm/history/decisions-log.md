# Log de Decisoes Tecnicas

Formato recomendado:
- `YYYY-MM-DD | status | decisao | contexto | impacto | referencia`

Entradas:
- `2026-04-15 | accepted | Adotar memoria tecnica local em .llm para padronizar operacao de agentes neste repositorio | Havia somente base compartilhada em ../.llm; faltava contexto operacional local estruturado | Onboarding mais rapido e menor risco de mudancas inconsistentes | .llm/README.md`
- `2026-04-15 | accepted | Registrar incertezas explicitamente com "Precisa de validacao" | Parte das informacoes de produto/roadmap nao esta 100% dedutivel do codigo | Evita alucinacao e deixa pendencias rastreaveis | .llm/idea.md`
- `2026-04-16 | accepted | Introduzir camada derivada de estado operacional no payload realtime de cabos sem quebrar contrato atual | MVP ja entregava itens e status, mas faltava interpretacao operacional do enlace (ocupacao/capacidade/erro) | Evolucao incremental: payload atual mantido e enriquecido com campos aditivos; frontend pode adotar gradualmente | app/services/network_maps/cable_metrics_payload_builder.rb; app/services/network_cables/operational_state_builder.rb; docs/api-contract.md`
