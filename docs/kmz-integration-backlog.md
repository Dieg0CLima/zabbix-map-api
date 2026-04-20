# Backlog Técnico — Integração KMZ

Este backlog transforma o plano `docs/kmz-integration-execution-plan.md` em entregas executáveis (issues + PRs) para implementação incremental.

## Visão geral de execução

- Ordem recomendada: Fase A -> Fase B -> Fase C -> Fase D
- Estratégia de merge: PRs pequenos, reversíveis e com teste por camada
- Regra de segurança: `preview` antes de `apply`

## Status de implementação (2026-04-20)

- Fase A: concluída (`A1`..`A5`)
- Fase B: concluída (`B1`..`B3`)
- Fase C: concluída (`C1`..`C3`)
- Fase D:
  - `D1` implementado no fluxo síncrono (guardrails de extensão/MIME/tamanho + timeout de parse)
  - `D2` implementado para trilha técnica básica (`import_id`, `timings_ms`, `counters`)
  - `D3` implementado no MVP (`apply` assíncrono com `ActiveJob` + endpoint de status por `import_id`)

## Fase A — Núcleo do pipeline (sem KMZ)

## Issue A1 — Contrato canônico v1

Objetivo:
- definir `ImportContract v1` e validações estruturais mínimas.

Escopo técnico:
- criar `app/services/maps/import/contracts/import_contract_v1.rb`
- validar campos obrigatórios: `schema_version`, `provider`, `coordinate_system`, `map`, `nodes`, `cables`
- validar tipos básicos e presença de `external_id`

Critério de aceite:
- contrato inválido retorna erros estruturados por campo.

---

## Issue A2 — Registry de providers

Objetivo:
- resolver provider por chave sem `case` espalhado.

Escopo técnico:
- criar `app/services/maps/import/provider_registry.rb`
- mapear inicialmente somente `kmz` (placeholder adapter)

Critério de aceite:
- provider desconhecido retorna erro de domínio consistente.

---

## Issue A3 — CanonicalNormalizer

Objetivo:
- normalizar e validar invariantes do contrato canônico.

Escopo técnico:
- criar `app/services/maps/import/canonical_normalizer.rb`
- validar unicidade de `external_id` em `nodes` e `cables`
- validar referências `source_external_id`/`target_external_id`
- normalizar enums (`status`, `cable_type`, `node_kind`)

Critério de aceite:
- payload inconsistente não passa para execução (`Executor`).

---

## Issue A4 — Executor (`preview`/`apply`)

Objetivo:
- executar importação sobre domínio atual.

Escopo técnico:
- criar `app/services/maps/import/executor.rb`
- modo `preview`: sem persistência, com resumo/diff
- modo `apply`: transação com upsert por `external_id`
- persistir `NetworkMap`, `MapNode`, `NetworkCable`, `NetworkCablePoint`

Critério de aceite:
- `apply` idempotente para mesma entrada.

---

## Issue A5 — Orquestrador único (`Run`)

Objetivo:
- encapsular fluxo end-to-end de importação.

Escopo técnico:
- criar `app/services/maps/import/run.rb`
- encadear: provider -> parse/normalize provider -> canonical normalize -> executor

Critério de aceite:
- serviço retorna `summary`, `report` e payload normalizado em `preview`.

---

## PRs sugeridos para Fase A

PR A.1:
- `ImportContractV1`, `ProviderRegistry`, testes unitários

PR A.2:
- `CanonicalNormalizer`, testes unitários/casos inválidos

PR A.3:
- `Executor` + `Run`, testes de serviço (`preview`/`apply`)

## Fase B — Adapter KMZ

## Issue B1 — Leitura de arquivo KMZ/KML

Objetivo:
- aceitar `.kmz` e `.kml` com parser confiável.

Escopo técnico:
- criar `app/services/maps/import/kmz/archive_reader.rb`
- extrair `doc.kml` do zip
- fallback para `.kml` puro

Critério de aceite:
- erro claro para arquivo corrompido/inválido.

---

## Issue B2 — Parser KML

Objetivo:
- converter XML KML em estrutura intermediária.

Escopo técnico:
- criar `app/services/maps/import/kmz/kml_parser.rb`
- parsear `Document`, `Folder`, `Placemark`, `Point`, `LineString`, `ExtendedData`

Critério de aceite:
- parser retorna estrutura consistente para geometrias suportadas no MVP.

---

## Issue B3 — `Providers::KmzAdapter`

Objetivo:
- adaptar KML/KMZ para `ImportContract`.

Escopo técnico:
- criar `app/services/maps/import/providers/base_adapter.rb`
- criar `app/services/maps/import/providers/kmz_adapter.rb`
- mapear `Point` -> `nodes` e `LineString` -> `cables + points`
- gerar `external_id` determinístico quando ausente

Critério de aceite:
- `Run(provider: "kmz")` produz payload canônico válido.

---

## PRs sugeridos para Fase B

PR B.1:
- `archive_reader` + `kml_parser` + testes

PR B.2:
- `kmz_adapter` + integração com `Run` + testes de serviço

## Fase C — API HTTP e autorização

## Issue C1 — Endpoints de importação

Objetivo:
- expor fluxo de importação para frontend.

Escopo técnico:
- adicionar rotas:
  - `POST /api/v1/network_maps/imports/preview`
  - `POST /api/v1/network_maps/imports/apply`
- criar `app/controllers/api/v1/network_map_imports_controller.rb`

Critério de aceite:
- endpoints funcionais com payload multipart e respostas padronizadas.

---

## Issue C2 — Segurança e escopo multi-tenant

Objetivo:
- garantir permissão correta para importação.

Escopo técnico:
- aplicar `authenticate_user!`
- aplicar `ensure_organization_access!`
- aplicar `require_editor_or_admin!`
- validar `organization_id` para admin global sem contexto

Critério de aceite:
- usuários sem permissão recebem `403`.

---

## Issue C3 — Contrato de resposta e documentação

Objetivo:
- padronizar resposta para frontend.

Escopo técnico:
- resposta `preview`: `summary`, `report`, `normalized_payload`, `warnings`, `target_map`
- resposta `apply`: `summary`, `report`, `network_map_id`, `network_map_name`
- atualizar `docs/api-contract.md`

Critério de aceite:
- contrato documentado e coberto por request tests.

---

## PRs sugeridos para Fase C

PR C.1:
- rotas + controller + autorização + request tests

PR C.2:
- documentação de contrato e exemplos no `api-contract.md`

## Fase D — Robustez e operação

## Issue D1 — Guardrails operacionais

Objetivo:
- proteger API contra importações problemáticas.

Escopo técnico:
- limite de tamanho do arquivo
- timeout de parsing
- validação de extensão e MIME

Critério de aceite:
- rejeição controlada para inputs inválidos/grandes.

---

## Issue D2 — Observabilidade

Objetivo:
- permitir diagnóstico de falhas e performance.

Escopo técnico:
- logs estruturados por `import_id`
- duração por etapa (`parse`, `normalize`, `validate`, `persist`)
- contadores (`created`, `updated`, `skipped`, `failed`)

Critério de aceite:
- execução de import produz trilha completa de auditoria técnica.

---

## Issue D3 — Modo assíncrono (evolução)

Objetivo:
- suportar arquivos grandes sem bloquear request.

Escopo técnico:
- enfileirar `apply` via ActiveJob/SolidQueue
- endpoint de status de execução

Critério de aceite:
- importação grande processa em background com polling de status.

## Matriz de dependências

- A1 -> A3
- A2 -> A5
- A3 -> A4 -> A5
- A5 -> B3
- B1 + B2 -> B3
- B3 -> C1
- C1 -> C3
- C1 + C2 -> D1/D2/D3

## Testes mínimos por fase

- Fase A: service tests (`contracts`, `normalizer`, `executor`, `run`)
- Fase B: service tests do adapter + fixtures KMZ/KML
- Fase C: request tests (`preview` e `apply`)
- Fase D: testes de erro/limite/timeout + job tests (quando assíncrono)

## Definition of Done por PR

- código com responsabilidades separadas (controller/service/provider)
- testes passando para camada alterada
- docs atualizadas (`api-contract` quando aplicável)
- sem quebra de compatibilidade em endpoints existentes
- logs sem exposição de conteúdo sensível do arquivo importado
