# AGENTS

## LLM Knowledge Base (Local + Shared)

Este repositório possui memória local em `.llm/` e também memória compartilhada em `../.llm/`.

- `.llm/`: contexto operacional deste projeto (`zabbix-map-api`) e instruções específicas para execução local.
- `../.llm/`: contexto compartilhado entre projetos `mcd/` e entre sessões/ferramentas.

### Ordem de leitura obrigatória no início da sessão
1. `.llm/README.md`
2. `.llm/idea.md`
3. `.llm/context/*.md` (arquitetura, módulos, fluxo, domínio, riscos)
4. `../.llm/README.md`, `../.llm/SKILLS.md` e `../.llm/HISTORY.md`

### Atualização obrigatória ao concluir trabalho significativo
1. Atualize o histórico local em `.llm/history/changes.md` e, quando aplicável, `.llm/history/decisions-log.md`.
2. Se criou padrão reutilizável local, atualize `.llm/skills/*`.
3. Se a decisão/padrão for útil para múltiplos projetos, replique no compartilhado (`../.llm/HISTORY.md`, `../.llm/skills/`).

---

## Project Overview
- Rails 8 API modeling multi-organization network maps, nodes, cables, events and Zabbix data; UI lives in `../zabbix-map-front`.
- Secure JWT auth via Devise + `devise-jwt`, membership RBAC (admin/editor/viewer/global) and canonical JSON:API payloads.
- Reliability priorities: multi-mode Zabbix (API/DB/hybrid), cache/infrastructure inside `solid_cache|solid_queue|solid_cable`, and compatibility with legacy vs. V2 map endpoints.

## Domain Summary
- Tenant gating happens through `Organization`, `Membership` (roles above) and `config/routes.rb` scopes; organization context is enforced via `app/controllers/concerns/organization_scoped`.
- Topology stack: `NetworkMap` anchors, `MapNode`/`MapNodeItem` define visual elements, `NetworkCable` + `NetworkCablePoint` represent polylines, while `NetworkCableItem` + `Event` attach devices/alerts; keep `legacy_network_maps` routes/functionality intact for older clients.
- Zabbix: `ZabbixConnection` (api/db/hybrid) with encrypted credentials, cached tables `zabbix_hosts`/`zabbix_items`, and helpers under `app/models/zabbix/*`; orchestration lives in `app/services/zabbix_*` and `Zabbix::Client`.
- Supporting entities (Site, Device, DeviceInterface, SiteMarker, DeviceMarker) feed the editor and dashboards; metrics expectations live in `docs/node-item-metrics-contract.md` and API contracts in `docs/api-contract.md`.

## Tech Stack
- Backend: Ruby 3.4.2, Rails 8.0.4, PostgreSQL primary + optional MySQL (`mysql2`), Puma, `jsonapi-serializer`, `solid_cache`/`solid_queue`/`solid_cable`, `kamal`, `thruster`.
- Security: Devise + `devise-jwt`, encrypted Devise/Zabbix secrets, request-wide RBAC context.
- Frontend: Vue 3 composition API, Pinia stores, dedicated services/composables, separate `types/` DTOs, PrimeVue UI kit backed by `../zabbix-map-front/llms.txt`, `llms-full.txt` and the PrimeVue MCP server; always sync API shades via `docs/api-contract.md`.

## Key Directories
- `app/controllers/api/v1/`: orchestration, authorization, error mapping; keep controllers thin and delegate to services/serializers.
- `app/services/`: one PORO per action grouping (`network_maps/*`, `zabbix_connections/*`, etc.); include payload builders near serializer concerns.
- `app/models/`: persistence, associations, validations, scopes, small invariants; avoid embedding workflows or integrations.
- `app/serializers/api/v1/`: response shaping per endpoint.
- `config/`: `routes.rb` hosts legacy and V2 namespaces; `database.yml` defines primary/cache/queue/cable shards.
- `db/`: migrations + schema; run `bin/rails db:prepare` when schema changes.
- `docs/`: canonical references—link them from AGENTS instead of duplicating.
- `test/`: request specs for HTTP, service specs for flows, model specs for invariants; match legacy naming for old endpoints.
- `docker/entrypoints`: scripts used by `docker-compose.yml`.
- `../zabbix-map-front`: standalone Vue app; inspect `services/`, `composables/`, `stores/`, `types/` before touching contracts or PrimeVue components.

## Local Development
- `bundle install`, then `bin/rails db:prepare` (honors `config/database.yml` env overrides).
- `bin/rails server -p 3000` for local API; `docker-compose up --build` leverages `docker/entrypoints`.
- Keep `.env`-style values for `DB_*`, JWT secrets, Zabbix credentials synchronized with Rails credentials (never commit raw secrets).
- API changes require a quick check of `../zabbix-map-front` DTOs/composables and `docs/api-contract.md` to avoid front/back drift.

## Test and Validation Commands
- `bin/rails test` (narrow via `test/services`, `test/controllers/api/v1`, etc. when possible).
- `bundle exec rubocop` (follows `.rubocop.yml` + `rubocop-rails-omakase`).
- `bundle exec brakeman` before merging controller/service touch points.
- `bin/rails db:test:prepare` when schema/migration changes precede tests.
- Rerun related front-side build/verifications whenever API payloads change.

## Backend Conventions
- Controllers in `app/controllers/api/v1/` remain thin; delegate to services/serializers/concerns (`organization_scoped`, error handlers).
- Services (`app/services/*`) own business logic; follow `docs/ENGINEERING_GUIDELINES.md` and `docs/architecture/service-pattern-api-v1.md` for SOLID orchestration.
- Models (`app/models/`) stay focused on persistence, associations, validations, scopes, and contained invariants; avoid fat models/controllers.
- Integrations (Zabbix, caches, third-party APIs) live outside models in `app/services/zabbix_*` and `Zabbix::Client`.
- Tests map to layers: request specs for endpoints, service specs for flows, model specs for local invariants.

## Frontend Conventions
- Front repo `../zabbix-map-front` uses Vue 3 composition-first style; components stay visual-only and consume composables/stores/services.
- Logic goes into composables, shared state into Pinia stores, HTTP calls into services, DTOs into `types/`; avoid `fetch` inside components and deep watchers.
- PrimeVue is the UI kit; consult `llms.txt`, `llms-full.txt`, and the PrimeVue MCP server before touching components/props/tokens.
- Keep API payload changes in sync with `docs/api-contract.md` and Pinia stores or services that consume them.

## API and Integration Rules
- `docs/api-contract.md` defines `network_maps`, `map_nodes`, `network_cables`, `zabbix_connections`, `zabbix_hosts/items` payloads/filters/status codes; update this doc with every API change.
- Legacy endpoints under `legacy_network_maps` and `legacy`-prefixed cables remain for existing clients; only adjust when doc+tests cover both legacy and V2 surfaces.
- Zabbix host/item endpoints read caches (`zabbix_hosts`, `zabbix_items`) or direct DB when `connection_mode` is `db`/`hybrid`; keep `limit`, `hostid`, `zabbix_host_id` semantics from README/API contract.
- Multi-org isolation, cable invariants, encrypted credentials, and KMZ flows are detailed in `docs/zabbix-map-architecture.md` and `docs/kmz-compatibility.md`; reference them before modifying related code.

## Documentation Map
- `.llm/README.md`: guia operacional da memória local para agentes.
- `.llm/idea.md`: objetivos, escopo e limites do projeto com incertezas explícitas.
- `.llm/context/*.md`: visão técnica rápida baseada em código real (arquitetura, módulos, fluxos, dependências, domínio, riscos).
- `.llm/conventions/*.md`: padrões de código, nomenclatura e princípios arquiteturais locais.
- `.llm/skills/*`: playbooks de execução recorrente (review, workflow de commit, etc.).
- `.llm/decisions/*`: ADR template e registro de decisões arquiteturais.
- `.llm/tasks/*`: template e instruções de execução de tarefas por agentes.
- `README.md`: quick intro, setup, and Zabbix host/item primer.
- `docs/ai-development-guidelines.md`: agent workflow, DoD, checklist, and mandatory doc-update rules.
- `docs/zabbix-map-architecture.md`: canonical domain overview, roadmap, security/RBAC expectations.
- `docs/api-contract.md`: API payloads/filters/status codes tied to front-end DTOs.
- `docs/ENGINEERING_GUIDELINES.md`: Rails + SOLID + Clean Code guidance for services/controllers/models.
- `docs/architecture/service-pattern-api-v1.md`: orchestration pattern for controllers/services and payload builders.
- `docs/architecture/backend-architecture-review.md`: targeted refactor notes; treat as snapshot and align with `docs/zabbix-map-architecture.md` before applying.
- `docs/kmz-compatibility.md`: KMZ/KML exporter/importer expectations.
- `docs/node-item-metrics-contract.md`: host/item metrics contract for dashboards.
- `../zabbix-map-front/llms.txt`, `llms-full.txt`, MCP server: PrimeVue component advice for UI changes.

## Safe Change Rules
- Read AGENTS.md, `.llm/README.md`, `.llm/context/*.md`, README.md, and every doc in this map before editing; flag contradictions and update AGENTS to note consolidated guidance.
- Every behavior/contract change must update documentation (`docs/ai-development-guidelines.md`, README, AGENTS, and the relevant doc in `docs/`).
- Every significant change must also update `.llm/history/changes.md` (and `.llm/history/decisions-log.md` when there is architectural decision/trade-off).
- Preserve organization scoping; do not mix global-admin logic into per-org services without explicit approval.
- Keep secrets encrypted (Devise, Zabbix); do not log raw credentials.
- Run `bundle exec brakeman` + `bundle exec rubocop` before declaring the change ready.

## Zabbix Live Values — Mandatory Service

**Always use `Zabbix::LiveValuesFetcher` whenever you need `lastvalue`/`lastclock` for `Zabbix::Item` records.**

```ruby
# Correct — always use the fetcher
zabbix_items = records.filter_map(&:zabbix_item)
live = Zabbix::LiveValuesFetcher.new(items: zabbix_items).call
lastvalue = live.dig(item.itemid.to_s, "value") || item.lastvalue
lastclock = live.dig(item.itemid.to_s, "clock")&.to_s || item.lastclock&.to_s

# Wrong — stale column data, never use directly for responses
item.lastvalue   # ❌ stale
item.lastclock   # ❌ stale
```

- Location: `app/services/zabbix/live_values_fetcher.rb`
- Groups items by `zabbix_connection_id` — one `HistoryCache` call per connection, no N+1
- Falls back to `{}` when the connection is not `db_enabled?` or on error
- Callers always fall back to stale columns: `live.dig(itemid, "value") || item.lastvalue`
- Already used in: `NetworkCableItems::PayloadBuilder`, `NetworkCableItemsController`, `Devices::Monitoring::ItemsController`, `NetworkMaps::CableMetricsPayloadBuilder`
- Every new endpoint or serializer that exposes Zabbix metric values **must** go through this service

## Regression & Scope Guards
- Leave `legacy_network_maps`/`legacy` cables intact unless tests/docs cover the legacy surface too.
- Touch `../zabbix-map-front` only when API contracts or UI behavior change.
- Document unavoidable multi-module edits (routes, serializers, services) directly in AGENTS.md and mention why additional files were touched.
- Use `solid_cache`/`solid_queue` shards or Zabbix services before reaching directly into caches or DB; avoid raw queries from controllers.

## Definition of Done
- [ ] Rails + SOLID guidelines satisfied (`docs/ENGINEERING_GUIDELINES.md`, service-pattern doc); controllers remain thin.
- [ ] Tests updated (request, service, model specs) and `bin/rails test` passes.
- [ ] Documentation updated (README, AGENTS, `.llm/`, `docs/ai-development-guidelines.md`, `docs/api-contract.md`, or other relevant doc).
- [ ] `bundle exec rubocop` and `bundle exec brakeman` executed; secrets stay encrypted.
- [ ] Front-end expectations verified (`docs/api-contract.md`, `../zabbix-map-front` DTOs/stores) for API changes.

## Agent Workflow
1. Read this AGENTS.md, `.llm/README.md`, `.llm/idea.md`, `.llm/context/*.md`, README.md, and the docs listed above; note contradictions/redundancies and consolidate before editing.
2. Identify the owning controller/service/model/serializer in `app/controllers/api/v1`, `app/services`, `app/models`, `app/serializers/api/v1`; review related tests.
3. Implement behavior in services/helpers, keep controllers orchestration-only, scope via concerns, and respect multi-org invariants.
4. Update/add request specs, service specs, and model specs; update front-end DTOs/services if contracts change.
5. Run `bin/rails test`, `bundle exec rubocop`, `bundle exec brakeman` (and `bin/rails db:test:prepare` when schema changes).
6. Update documentation (README, AGENTS, `.llm/`, `docs/`), mention doc updates in the PR description, and confirm front-end contract compatibility.
