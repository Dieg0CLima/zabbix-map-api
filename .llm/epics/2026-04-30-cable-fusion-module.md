# Epic: Módulo de Diagrama de Fusão Integrado ao Fluxo de Cabos

## Status
- Estado: `in_progress`
- Dono técnico: backend + frontend maps/inventory
- Data: `2026-04-30`

## Contexto do projeto (real)
- Backend Rails 8 API em `app/controllers/api/v1`, `app/services`, `app/models`.
- Frontend separado em `../zabbix-map-front`.
- Domínio atual de cabos: `NetworkCable`, `NetworkCablePoint`, `NetworkCableItem`, métricas operacionais e integração Zabbix.
- Diretriz atual: operação em `TENANCY_MODE=single` (sem fluxo multi-tenant no login).

## Problema
- O sistema modela geometria e monitoramento de cabos, mas não modela engenharia de fusão de fibras.
- Falta fluxo nativo para edição/validação/publicação de diagrama de fusão vinculado ao cabo.

## Objetivos
1. Integrar diagrama de fusão como subdomínio de `NetworkCable`.
2. Permitir edição em draft, validação e publicação versionada.
3. Separar saúde de fusão (`fusion_state`) da saúde operacional (`zabbix_status`/telemetria).
4. Expor contrato de API estável para editor visual no frontend.

## Escopo IN (MVP -> evolução)
- Namespace explícito `CableFusion::*`.
- `Diagram` 1:1 com `NetworkCable`.
- Persistência híbrida: estado atual normalizado + snapshot JSONB por versão publicada.
- Endpoints v1: `GET/PUT/validate/publish` + snapshots.
- Integração ao fluxo de criação de cabo: criar diagrama `draft` automaticamente (ou lazy-create no primeiro GET).

## Escopo OUT (fase posterior)
- Colaboração multiusuário em tempo real no editor.
- Templates avançados e importação/exportação externa.
- Regras operacionais extremamente granulares de auditoria na fase inicial.

## Decisões fechadas
1. Não usar nomes genéricos (`FusionNode`, etc.); usar namespace `CableFusion`.
2. Não sobrescrever estado operacional do cabo com estado de fusão.
3. Publicação é explícita e só ocorre com validação completa aprovada.
4. DTO único para o editor; persistência estruturada no backend.

## Modelo de domínio alvo (backend)
- `CableFusion::Diagram`
  - `network_cable_id`, `status`, `version`, `published_at`, `published_by_id`,
    `last_validated_at`, `validation_errors_count`, `structure_checksum`, `lock_version`.
- `CableFusion::Node`
  - `diagram_id`, `node_type`, `label`, `x`, `y`, `rotation`, `metadata`.
- `CableFusion::Port`
  - `node_id`, `name`, `port_type`, `capacity`, `occupancy_limit`, `position_x`, `position_y`, `metadata`.
- `CableFusion::Link`
  - `diagram_id`, `source_port_id`, `target_port_id`, `link_kind`, `fiber_side`, `fiber_number`, `status`, `metadata`.
- `CableFusion::Snapshot`
  - `diagram_id`, `version`, `payload`, `created_by_id`, `reason`, `published`.

## Regras de negócio essenciais
- Estrutural: portas válidas, links não órfãos, `source != target`, compatibilidade de tipo.
- Capacidade: sem overbooking de porta/fibra.
- Publicação: bloqueada se houver inconsistências.
- Referência de fibra determinística: `network_cable_id + side(a|b) + fiber_number`.

## API alvo (v1)
- `GET /api/v1/network_cables/:id/fusion_diagram`
- `PUT /api/v1/network_cables/:id/fusion_diagram`
- `POST /api/v1/network_cables/:id/fusion_diagram/validate`
- `POST /api/v1/network_cables/:id/fusion_diagram/publish`
- `GET /api/v1/network_cables/:id/fusion_diagram/snapshots`
- `POST /api/v1/network_cables/:id/fusion_diagram/snapshots/:snapshot_id/restore`

## Integração com métricas
- Adicionar dimensão paralela no payload de cabo:
  - `fusion_state`
  - `fusion_occupancy_percent`
  - `fusion_alerts_count`
  - `published_version`

## Fases de rollout
1. Fundação
  - Migrations + models + services base (`load/persist/validate`) + endpoints `GET/PUT/validate`.
2. Consistência
  - Publicação + snapshots + validadores especializados + projeções de saúde.
3. Operação
  - Rollback, lock otimista, UX de conflitos no editor.
4. Evolução
  - Recursos avançados (templates/import/export/collab).

## Dependências
- Backend: `docs/api-contract.md`, services `network_cables/*`, payload builders de métricas.
- Frontend: `../zabbix-map-front` (nova view/aba de fusão e service HTTP).

## Riscos
- Misturar fusão com telemetria de cabo (evitar: estados separados).
- Subestimar validação de referência de fibra.
- Aumentar complexidade cedo demais (mitigar por fases).

## Checklist de execução inicial
- [x] Criar migrations `cable_fusion_*`.
- [x] Criar models e associações com `NetworkCable`.
- [x] Implementar services `CableFusion::LoadDiagram`, `PersistDraft`, `ValidateDraft`.
- [x] Expor endpoints v1 iniciais.
- [x] Atualizar `docs/api-contract.md`.
- [ ] Adicionar testes request + service.

## Progresso recente
- Fase 2 (parcial) iniciada:
  - endpoint `publish` implementado com snapshot imutável por versão;
  - listagem de snapshots implementada;
  - restore de snapshot para novo draft implementado;
  - `cable_metrics` passou a expor dimensões de fusão (`fusion_state`, ocupação, alertas, versão publicada).
