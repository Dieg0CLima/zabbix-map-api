# Revisão Arquitetural do Backend — Zabbix Map API

## 1) Resumo da Solução

O backend já possui uma base sólida: controllers delegam para services, models mantêm
validações e associações, e existe boa separação em namespaces. Porém, a análise revelou
**5 categorias de melhorias** concretas:

| # | Problema | Impacto | Localização |
|---|----------|---------|-------------|
| 1 | **RegistrationsController gordo** — orquestra criação de User + Organization + Membership + serialização inline | Viola "controller fino" e dificulta teste isolado | `app/controllers/api/v1/users/registrations_controller.rb:6-73` |
| 2 | **SessionsController com serialização duplicada** — `serialized_organization` replicada em registrations e sessions | DRY / violação SRP | `app/controllers/api/v1/users/sessions_controller.rb:42-51` |
| 3 | **NetworkCablesController com filtros inline** — `apply_filters` (25 linhas de queries/ILIKE/JSON cast) dentro do controller | SQL no controller, viola SRP, dificulta teste e reuso | `app/controllers/api/v1/network_cables_controller.rb:105-136` |
| 4 | **Escopo de organização duplicado em 8+ controllers** — `network_maps_scope`, `zabbix_connections_scope` replicados | Violação DRY, risco de inconsistência | Todos os controllers de recursos |
| 5 | **Formato de erro inconsistente** — `render_validation_error` usa `{code, message, details}`, Zabbix controllers usam `{error, details}`, DomainError usa `{error: {code, message, details}}` | Dificulta consumo no frontend | Vários controllers |

### Diagnóstico Detalhado

#### Controllers Gordos

**`RegistrationsController`** (linhas 6-73):
- `create` gerencia transação com `resource.save!` + `ensure_registration_organization!`
- `ensure_registration_organization!` resolve org (por ID ou criando nova) + cria Membership
- `respond_with` serializa User + Organization inline
- `selected_organization` contém lógica de decisão (criar vs buscar)
- **Solução**: Extrair `Users::Register` service

**`NetworkCablesController#apply_filters`** (linhas 105-130):
- 7 condicionais de filtro com SQL inline (`ILIKE`, `metadata ->>`, `::int`)
- `resolve_pop_filter` faz lookup de external_id
- **Solução**: Extrair `NetworkCables::FilterQuery` query object

#### Models — Avaliação

Os models estão **bem disciplinados**:
- `NetworkCable`: callbacks apenas para defaults visuais e resolução de external_id — são invariantes locais da entidade, legítimos no model
- `MapNode`, `MapPop`: idem, callbacks simples de defaults
- `Organization#ensure_slug`: regra local, ok no model
- `ZabbixConnection`: apenas validações condicionais, sem lógica de workflow
- Nenhum model chama API externa diretamente

**Veredicto**: Nenhum model está "gordo" no sentido clássico. As regras nos callbacks são invariantes da entidade (defaults, resolução de FK por external_id), não workflows de negócio.

#### Anti-patterns Encontrados

| Anti-pattern | Onde | Severidade |
|-------------|------|-----------|
| Lógica de orquestração no controller | `RegistrationsController#create` | Alta |
| SQL / queries no controller | `NetworkCablesController#apply_filters` | Média |
| Serialização inline duplicada | `serialized_organization` em 2 controllers | Média |
| Escopo de tenant duplicado | `network_maps_scope` em 5+ controllers | Média |
| Formato de erro inconsistente | 3 formatos diferentes | Média |

---

## 2) Estrutura Arquitetural Sugerida

### Arquitetura Atual (já boa)
```
app/
├── controllers/api/v1/     # Delegam para services ✅
├── models/                 # Validações + associações ✅
├── services/
│   ├── {resource}/create.rb
│   ├── {resource}/update.rb
│   ├── {resource}/destroy.rb
│   └── {resource}/payload_builder.rb
```

### Arquitetura-Alvo (incremento mínimo)
```
app/
├── controllers/
│   ├── concerns/
│   │   ├── organization_scoped.rb    # NOVO: extrai escopo de org
│   │   ├── domain_error_handler.rb   # NOVO: padroniza erros
│   │   ├── editor_state_params.rb    # existente
│   │   └── rack_sessions_fix.rb      # existente
│   └── api/v1/...
├── models/                            # SEM MUDANÇAS (já disciplinados)
├── services/
│   ├── users/
│   │   └── register.rb               # NOVO: extrai do RegistrationsController
│   ├── network_cables/
│   │   ├── filter_query.rb           # NOVO: extrai do CablesController
│   │   └── ...existentes
│   └── ...existentes
```

### O que permanece no model (invariantes locais)
- `NetworkCable`: `apply_default_visuals`, `resolve_pop_external_ids`, `derive_pops_from_nodes` — são invariantes da entidade
- `MapNode`: `resolve_map_pop_external_id`, `apply_default_visuals`
- `MapPop`: `apply_defaults`, `ensure_no_dependencies`
- `Organization`: `ensure_slug`

### O que sai dos controllers para services
- `RegistrationsController#create` → `Users::Register`
- `NetworkCablesController#apply_filters` → `NetworkCables::FilterQuery`

### Estratégia de permissões
O RBAC atual via `require_editor_or_admin!` no ApplicationController é adequado para o porte do projeto. Pundit/Policy Objects seria overengineering neste estágio. Recomendo evolução para policies somente quando surgirem permissões condicionais por recurso.

### Padronização de payloads
Todos os endpoints devem seguir:
- Sucesso: `{ data: ... }`
- Erro de validação: `{ code: "VALIDATION_ERROR", message: "...", details: {...} }`
- Erro de domínio: `{ code: "DOMAIN_ERROR_CODE", message: "...", details: {...} }`
- Erro de infra: `{ code: "SERVICE_UNAVAILABLE", message: "...", details: "..." }`

---

## 3) Plano de Refatoração em Etapas

### PR#1: Extrações de maior impacto + concern de scoping
**Arquivos novos:**
- `app/services/users/register.rb`
- `app/services/network_cables/filter_query.rb`
- `app/controllers/concerns/organization_scoped.rb`
- `app/controllers/concerns/domain_error_handler.rb`

**Arquivos modificados:**
- `app/controllers/api/v1/users/registrations_controller.rb` (fica fino)
- `app/controllers/api/v1/network_cables_controller.rb` (remove apply_filters)

**Objetivos:**
- Controller de registro fica com ~15 linhas
- Filtros de cabos reutilizáveis e testáveis isoladamente
- Escopo de organização DRY

**Riscos:**
- Baixo: refatoração interna sem mudança de API/payloads
- Testar fluxo de sign_up end-to-end após extração

### PR#2: Padronização de erros e serialização
**Arquivos modificados:**
- `app/controllers/api/v1/zabbix_hosts_controller.rb`
- `app/controllers/api/v1/zabbix_items_controller.rb`
- `app/controllers/application_controller.rb`

**Objetivos:**
- Formato de erro unificado: `{code, message, details}`
- Remover duplicação de `serialized_organization`

**Riscos:**
- Médio: frontend precisa adaptar parsing de erros Zabbix
- Documentar breaking change no formato de erro

### PR#3: Cobertura de testes
**Arquivos novos:**
- `test/services/users/register_test.rb`
- `test/services/network_cables/filter_query_test.rb`
- `test/controllers/api/v1/users/registrations_controller_test.rb` (request spec)
- `test/controllers/api/v1/network_cables_filter_test.rb` (request spec)

**Objetivos:**
- 100% cobertura dos services extraídos
- Request specs para fluxos críticos
- Sem HTTP real para services

**Riscos:**
- Baixo: apenas adição de testes

---

## 4) Código — Antes vs Depois

### Caso 1: RegistrationsController → Users::Register

**Antes** (`app/controllers/api/v1/users/registrations_controller.rb`):
```ruby
def create
  build_resource(sign_up_params)
  ActiveRecord::Base.transaction do
    resource.save!
    ensure_registration_organization!(resource)
  end
  sign_up(resource_name, resource)
  respond_with resource, location: after_sign_up_path_for(resource)
rescue ActiveRecord::RecordInvalid
  clean_up_passwords resource
  set_minimum_password_length
  render json: { errors: resource.errors.full_messages }, status: :unprocessable_entity
end
```

**Depois** — controller fino, service com 1 ação:
Ver arquivos gerados em `app/services/users/register.rb` e controller refatorado.

### Caso 2: NetworkCablesController#apply_filters → NetworkCables::FilterQuery

**Antes** (`app/controllers/api/v1/network_cables_controller.rb:105-136`):
```ruby
def apply_filters(scope)
  scope = scope.where(status: params[:status]) if params[:status].present?
  scope = scope.where(cable_type: params[:cable_type]) if params[:cable_type].present?
  if params[:network_role].present?
    scope = scope.where("metadata ->> 'network_role' = ?", params[:network_role])
  end
  # ... mais 15 linhas de SQL inline
end
```

**Depois** — query object reutilizável, controller limpo:
Ver arquivo gerado em `app/services/network_cables/filter_query.rb`.

---

## 5) Checklist SOLID Aplicado

### S — Single Responsibility
- [x] `Users::Register` → 1 ação: registrar usuário com org
- [x] `NetworkCables::FilterQuery` → 1 ação: filtrar cabos
- [x] Controllers → apenas receber request, invocar service, retornar response
- [x] Models → apenas persistência, associações, invariantes locais

### O — Open/Closed
- [x] `FilterQuery` aceita novos filtros sem modificar controller
- [x] `DomainErrorHandler` concern permite handlers por tipo sem modificar ApplicationController
- [x] Event system (`EventTypeInferer`) extensível por novos tipos

### L — Liskov Substitution
- [x] Todos os services seguem interface `initialize(deps) + call` → substituíveis
- [x] PayloadBuilders intercambiáveis (NetworkMaps vs NetworkProjects)

### I — Interface Segregation
- [x] Concerns separados: `OrganizationScoped`, `DomainErrorHandler`, `EditorStateParams`
- [x] Controllers incluem apenas os concerns que precisam

### D — Dependency Inversion
- [x] Services recebem dependências via construtor (network_map:, organization:)
- [x] `Zabbix::DatabaseConnection` abstrai adapter (PG/MySQL)
- [x] `ZabbixHosts::Fetch` delega para fetcher correto via composição
