# Zabbix Map API — Estrutura e Diretrizes de Consistência

Este documento descreve a **estrutura atual** do projeto e propõe um padrão de evolução para atender ao objetivo de um sistema de mapas integrado ao Zabbix.

## 1) Objetivo do projeto

Construir uma API Rails multi-tenant para:

- autenticação de usuários;
- isolamento por organização;
- integração com Zabbix para leitura de hosts, triggers e links;
- composição e persistência de mapas operacionais;
- disponibilização de dados para front-end de visualização de mapas.

---

## 2) Estado atual (avaliação)

Atualmente o projeto já possui uma base sólida de autenticação e organização:

- **Autenticação JWT com Devise** (`User`, controllers de `sessions` e `registrations`);
- **Contexto multi-organização** com `Organization` e `Membership` (roles `admin/editor/viewer`);
- Endpoint autenticado para sessão atual (`GET /api/v1/me`).

### Pontos fortes

- Base de segurança já iniciada com JWT;
- Estrutura inicial de RBAC por organização;
- Versionamento de API (`/api/v1`) pronto para evoluções sem quebra.

### Lacunas para integração com mapas do Zabbix

- Não há modelos para domínio de mapa (mapa, nó, link, layout);
- Não há camada explícita de integração com Zabbix (client/adapters/services);
- Não há políticas de autorização por recurso (ex.: Pundit/CanCan);
- Não há endpoints de negócio para sincronização e leitura de dados operacionais.

---

## 3) Estrutura alvo recomendada

## 3.1 Organização de código

Adotar a seguinte separação para manter consistência:

- `app/controllers/api/v1/...`: apenas HTTP, validação superficial e serialização;
- `app/services/...`: regras de negócio e orquestração;
- `app/clients/zabbix/...`: cliente HTTP/JSON-RPC para Zabbix;
- `app/models/...`: entidades e validações de domínio;
- `app/policies/...` (se adotado): autorização por recurso e ação;
- `app/serializers/...` (ou Jbuilder): contrato de resposta da API.

## 3.2 Domínio mínimo sugerido

Modelos iniciais para mapas:

- `Map`
  - `organization_id`, `name`, `description`, `zabbix_mapid` (opcional), `source_type` (`zabbix`, `manual`, `hybrid`)
- `MapNode`
  - `map_id`, `node_type` (`host`, `host_group`, `trigger`, `shape`, `text`), `label`, `x`, `y`, `metadata:jsonb`, `zabbix_ref`
- `MapLink`
  - `map_id`, `from_node_id`, `to_node_id`, `link_type`, `metadata:jsonb`
- `ZabbixConnection`
  - `organization_id`, `base_url`, `api_token` (criptografado), `default` (boolean)
- `SyncJob` (opcional)
  - auditoria de sincronizações, status, erros e tempo de execução

## 3.3 Fluxo de integração com Zabbix

1. Usuário autentica na API (`JWT`).
2. API resolve organização ativa (via membership/contexto).
3. Service consulta `ZabbixConnection` da organização.
4. `Zabbix::Client` executa chamadas JSON-RPC.
5. Service normaliza payload em entidades internas (`Map`, `MapNode`, `MapLink`).
6. API responde em contrato estável para o front-end.

---

## 4) Convenções de consistência

## 4.1 API e versionamento

- Manter tudo em `/api/v1`;
- Toda resposta deve retornar envelope consistente (`data`, `meta`, `errors` quando aplicável);
- Paginação padrão para coleções (`page`, `per_page`).

## 4.2 Segurança

- Nunca retornar segredos (`api_token`) em responses;
- Armazenar credenciais de integração de forma criptografada;
- Exigir autorização por organização em toda operação de mapas;
- Log sanitizado para evitar vazamento de payload sensível.

## 4.3 Regras de autorização (RBAC)

- `admin`: gerencia conexão Zabbix, usuários e mapas;
- `editor`: cria/edita mapas e sincroniza dados;
- `viewer`: apenas leitura.

## 4.4 Estratégia de erros

Padronizar códigos e payloads:

- `401` não autenticado;
- `403` sem permissão;
- `404` recurso inexistente/no escopo da organização;
- `422` validação;
- `502/503` indisponibilidade externa (Zabbix).

---

## 5) Roadmap incremental sugerido

### Fase 1 — Fundação de domínio

- Criar `Map`, `MapNode`, `MapLink`, `ZabbixConnection`;
- Criar migrations com índices por `organization_id` e chaves de integridade;
- Implementar endpoints CRUD de mapas.

### Fase 2 — Integração Zabbix

- Implementar `Zabbix::Client` (autenticação + chamadas JSON-RPC);
- Criar services de import/sync (`Maps::SyncFromZabbix`);
- Registrar falhas e métricas básicas de sincronização.

### Fase 3 — Governança e escalabilidade

- Adotar policies para autorização granular;
- Testes de request + serviços de integração;
- Jobs assíncronos para sincronização e refresh periódico;
- Observabilidade (logs estruturados + tracing + métricas).

---

## 6) Critérios de pronto (Definition of Done)

Qualquer nova feature de mapas/Zabbix deve incluir:

- modelagem e migrations;
- endpoint versionado;
- autorização por organização/role;
- testes (model + request + service, quando aplicável);
- documentação atualizada (`README` + este documento).

---

## 7) Próximos artefatos recomendados

- `docs/api-contract.md` com exemplos de request/response;
- `docs/rbac.md` com matriz de permissões por role;
- `docs/zabbix-integration.md` com catálogo de métodos JSON-RPC usados.
