# Zabbix Map API — Estrutura e Diretrizes de Consistência

Este documento descreve a **estrutura atual** do projeto e propõe um padrão de evolução para atender ao objetivo de um sistema de mapas integrado ao Zabbix.

## 1) Objetivo do projeto

Construir uma API Rails multi-tenant para:

- autenticação de usuários;
- isolamento por organização;
- integração com Zabbix para leitura de hosts, triggers e links;
- composição e persistência de mapas de rede;
- disponibilização de dados para front-end de visualização de topologia.

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

- domínio de mapas de rede/cabos ainda em evolução;
- ausência de client/service explícitos para integração Zabbix;
- políticas de autorização por recurso ainda não implementadas;
- inexistência de endpoints de sincronização de topologia.

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

## 3.2 Modelagem de rede (foco em linhas/cabos)

A modelagem para representar cabos e linhas entre equipamentos deve seguir este desenho:

- `NetworkMap`
  - escopo por organização;
  - identifica a topologia (manual, zabbix ou híbrida).

- `MapNode`
  - representa equipamentos/entidades no canvas (switch, router, server, etc.);
  - possui coordenadas base (`x`, `y`) para renderização.

- `NetworkCable`
  - representa a conexão entre dois nós (`source_node` e `target_node`);
  - guarda tipo (`copper`, `fiber`, `wireless`, `logical`), status (`up/down/degraded/unknown`), capacidade e metadados.

- `NetworkCablePoint`
  - define os pontos intermediários da linha (polyline), permitindo desenhar curvas/quebras de cabo no mapa;
  - ordenado por `position`.

### 3.2.1 Regras essenciais de integridade

- `source_node` e `target_node` devem ser diferentes;
- ambos os nós devem pertencer ao mesmo `NetworkMap` do cabo;
- não permitir duplicidade da mesma conexão no mesmo mapa (`network_map_id + source_node_id + target_node_id`);
- pontos de cabo devem ter `position` única por cabo.

## 3.3 Fluxo de integração com Zabbix

1. Usuário autentica na API (`JWT`).
2. API resolve organização ativa (via membership/contexto).
3. Service consulta conexão Zabbix da organização.
4. `Zabbix::Client` executa chamadas JSON-RPC.
5. Service normaliza payload para `NetworkMap`, `MapNode` e `NetworkCable`.
6. API responde em contrato estável para o front-end.

---


## 3.4 Renderização no frontend e coordenadas

Para renderização de cabos:

- cada cabo deve ser composto por `[origem, ...pontos_intermediarios, destino]`;
- os pontos intermediários são definidos por `NetworkCablePoint` ordenado por `position`;
- o frontend pode renderizar via SVG (`polyline`) no MVP e evoluir para Canvas/WebGL em alta escala.

Para compatibilidade com KMZ/KML e formatos GIS, recomenda-se explicitar em `NetworkMap` um `coordinate_system` (`screen|geo`).

- `screen`: coordenadas de canvas (edição/topologia);
- `geo`: coordenadas geográficas (export/import KML/KMZ/GeoJSON).

## 3.5 Múltiplas conexões Zabbix e cache local

Para suportar múltiplos ambientes/clientes Zabbix por organização, adotar:

- `ZabbixConnection` como entidade de conexão com `connection_mode` (`api`, `db`, `hybrid`), status e conexão padrão;
- vínculo opcional de `NetworkMap` com `ZabbixConnection` para origem do mapa;
- namespace `app/models/zabbix` para cache estruturado dos dados coletados:
  - `Zabbix::Host` (tabela `zabbix_hosts`)
  - `Zabbix::Item` (tabela `zabbix_items`)


### Campos de formulário de conexão

Para suportar API e conexão direta com banco do Zabbix, o formulário deve contemplar:

- campos gerais: `name`, `connection_mode`, `default_connection`;
- quando `connection_mode = api` ou `hybrid`:
  - `base_url`, `api_token`;
- quando `connection_mode = db` ou `hybrid`:
  - `db_adapter`, `db_host`, `db_port`, `db_name`, `db_username`, `db_password`.

Tokens e senhas devem ser armazenados de forma criptografada.

### Estratégia de ingestão

1. API recebe/atualiza conexões em `ZabbixConnection`;
2. job/service consulta API Zabbix por conexão;
3. resposta é normalizada e persistida em `zabbix_hosts` e `zabbix_items`;
4. mapas e visões usam este cache para reduzir acoplamento e melhorar performance.

## 4) Convenções de consistência

## 4.1 API e versionamento

- Manter tudo em `/api/v1`;
- Toda resposta deve retornar envelope consistente (`data`, `meta`, `errors` quando aplicável);
- Paginação padrão para coleções (`page`, `per_page`).

## 4.2 Segurança

- Nunca retornar segredos em responses;
- Armazenar credenciais de integração de forma criptografada;
- Exigir autorização por organização em toda operação de mapas;
- Log sanitizado para evitar vazamento de payload sensível.

## 4.3 Regras de autorização (RBAC)

- `admin`: gerencia integração Zabbix, usuários e mapas;
- `editor`: cria/edita topologia e sincroniza dados;
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

- implementar modelos/migrations de `NetworkMap`, `MapNode`, `NetworkCable` e `NetworkCablePoint`;
- expor CRUD de mapas e nós;
- expor CRUD de cabos e pontos de rota.

### Fase 2 — Integração Zabbix

- implementar `Zabbix::Client` (autenticação + chamadas JSON-RPC);
- criar services de import/sync (`Maps::SyncFromZabbix`);
- registrar falhas e métricas básicas de sincronização.

### Fase 3 — Governança e escalabilidade

- adotar policies para autorização granular;
- testes de request + serviços de integração;
- jobs assíncronos para sincronização e refresh periódico;
- observabilidade (logs estruturados + tracing + métricas).

---

## 6) Critérios de pronto (Definition of Done)

Qualquer nova feature de mapas/Zabbix deve incluir:

- modelagem e migrations;
- endpoint versionado;
- autorização por organização/role;
- testes (model + request + service, quando aplicável);
- documentação atualizada (`README` + este documento).
