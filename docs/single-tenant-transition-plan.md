# Plano de Transição — Multi-tenant -> Single-tenant por Instalação

## Objetivo

Migrar esta API para operar como **single-tenant por instalação** (um cliente por deploy), preservando estabilidade operacional e abrindo caminho para um **control plane central** no futuro.

## Status atual

- Fase 0 iniciada:
  - `Tenancy::Resolver` introduzido no backend;
  - `TENANCY_MODE` suportado com default `multi`;
  - `ApplicationController#current_organization` delegando para o resolver.
- Avanços já aplicados:
  - `SessionsController` aceita login sem `organization_id` no modo `single`;
  - login possui fallback explícito de emissão de JWT quando `warden-jwt_auth.token` não vier preenchido.
- Com `TENANCY_MODE=multi`, o comportamento segue compatível com o fluxo atual de seleção por organização.

## Contexto atual

Hoje a API implementa multi-tenant lógico com:

- `Organization` + `Membership` (RBAC por organização),
- resolução dinâmica de `current_organization` por `organization_id/org_id`,
- escopo em controllers via `OrganizationScoped`,
- contrato HTTP que frequentemente exige `organization_id`.

Para o novo modelo, isso passa a ser excesso de complexidade no data plane.

## Arquitetura alvo

## 1) Data Plane (esta API)

- Cada instalação atende **apenas 1 tenant**.
- `current_organization` deixa de ser decidido por request e passa a ser fixo.
- API não depende de `organization_id` vindo do cliente.
- RBAC simplificado para papéis locais da instalação (ex.: `admin/editor/viewer` no próprio tenant).

## 2) Control Plane (futuro)

- Sistema separado para cadastro/provisionamento de tenants.
- Catálogo central de instalações, licença, status e operações de ciclo de vida.
- Sem acoplamento direto ao domínio operacional do mapa/Zabbix desta API.

---

## Estratégia de migração (sem ruptura)

## Fase 0 — Preparação e feature flag

Adicionar modo de tenancy por ambiente:

- `TENANCY_MODE=multi` (default inicial)
- `TENANCY_MODE=single`

Criar serviço de resolução único:
- `Tenancy::Resolver.current_organization(user:, params:)`

No modo `single`, sempre retorna a organização local da instalação.

Critério de aceite:
- sem mudança funcional em produção enquanto `TENANCY_MODE=multi`.

---

## Fase 1 — Single-tenant compatível com contrato atual

Objetivo:
- ativar modo single sem quebrar frontend imediatamente.

Mudanças:
- `organization_id` deixa de ser obrigatório no backend quando `TENANCY_MODE=single`.
- se `organization_id` vier na request, ele é aceito apenas para compatibilidade.
- `ensure_organization_access!` passa a validar apenas existência do tenant local + autenticação.
- `admin_without_organization_context?` torna-se irrelevante no modo single.

Critério de aceite:
- chamadas existentes com e sem `organization_id` funcionam no modo single.

---

## Fase 2 — Simplificação de autenticação e RBAC local

Objetivo:
- remover dependência de membership cross-org no data plane.

Mudanças:
- login não precisa selecionar organização.
- remover ramificações de `user.admin?` para acesso cross-organization.
- RBAC local: manter `require_editor_or_admin!` baseado em papel local do usuário na instalação.

Critério de aceite:
- fluxo de login e autorização sem referência a múltiplas organizações.

---

## Fase 3 — Limpeza de contrato e código legado multi-tenant

Objetivo:
- reduzir ruído técnico no data plane.

Mudanças:
- remover `organization_id` dos endpoints/documentação do data plane.
- remover/encolher concern `OrganizationScoped` para seleção fixa.
- eliminar caminhos de `current_user.organizations.find_by(...)`.
- atualizar testes de request para não depender de `organization_id`.

Critério de aceite:
- API do data plane sem semântica multi-tenant.

---

## Fase 4 — Introdução do Control Plane (separado)

Objetivo:
- gerenciar tenants fora desta API.

Escopo esperado:
- cadastro de tenant,
- provisionamento de instalação,
- ativação/suspensão/licenciamento,
- inventário de versões e health por tenant.

Critério de aceite:
- nenhuma regra de catálogo global no data plane.

---

## Backlog técnico prioritário

1. Criar `Tenancy::Resolver` com modo `multi|single`.
2. Refatorar `ApplicationController#current_organization` para usar resolver.
3. Adaptar `ensure_organization_access!` para comportamento por modo.
4. Adaptar `SessionsController` para não depender de `organization_id` em `single`.
5. Atualizar contrato da API (`docs/api-contract.md`) com semântica por `TENANCY_MODE`.
6. Atualizar testes de auth/controllers com cenários `multi` e `single`.
7. Remover ramificações legadas após estabilização em produção.

---

## Riscos e mitigação

- Risco: quebrar clientes que ainda enviam `organization_id`.
  - Mitigação: fase de compatibilidade (ignorar no single em vez de rejeitar).
- Risco: regressão de permissão ao remover membership.
  - Mitigação: introduzir matriz de autorização local explícita antes da remoção.
- Risco: mistura de responsabilidades data plane/control plane.
  - Mitigação: separar roadmap e repositório/serviço para control plane.

---

## Rollout recomendado

1. Deploy com `TENANCY_MODE=multi` (sem impacto).
2. Habilitar `TENANCY_MODE=single` em ambiente piloto.
3. Validar login, CRUD principal e importação KMZ sem `organization_id`.
4. Expandir para novas instalações.
5. Só então remover código legado multi-tenant.

---

## Definição de pronto da transição (data plane)

- API funciona sem `organization_id` em produção single-tenant.
- autorização local estável (`admin/editor/viewer`).
- docs e testes atualizados para o novo modo.
- caminhos multi-tenant legados removidos ou isolados por feature flag.
