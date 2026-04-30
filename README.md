# Zabbix Map API

API em Ruby on Rails para autenticação, multi-organização e evolução de um sistema de mapas integrado ao Zabbix.

## Documentação

- Visão de estrutura e diretrizes de consistência: [`docs/zabbix-map-architecture.md`](docs/zabbix-map-architecture.md)
- Guia de desenvolvimento assistido por IA e padrão de documentação contínua: [`docs/ai-development-guidelines.md`](docs/ai-development-guidelines.md)
- Contrato sugerido para renderização no frontend: [`docs/api-contract.md`](docs/api-contract.md)
- Compatibilidade e estratégia para KMZ/KML e correlatos: [`docs/kmz-compatibility.md`](docs/kmz-compatibility.md)
- Plano de execução da integração KMZ (importação desacoplada): [`docs/kmz-integration-execution-plan.md`](docs/kmz-integration-execution-plan.md)
- Backlog técnico da integração KMZ (issues e PRs por fase): [`docs/kmz-integration-backlog.md`](docs/kmz-integration-backlog.md)
- Plano de arquitetura para importação desacoplada por múltiplos providers (KMZ, OzMap, GeoSite): [`docs/import-providers-architecture-plan.md`](docs/import-providers-architecture-plan.md)
- Plano de transição de tenancy (multi-tenant lógico -> single-tenant por instalação + control plane): [`docs/single-tenant-transition-plan.md`](docs/single-tenant-transition-plan.md)
- Modelo de múltiplas conexões Zabbix e cache de hosts/items: ver seção 3.5 em [`docs/zabbix-map-architecture.md`](docs/zabbix-map-architecture.md)
- Plano de evolução para atualização quase real-time do mapa: [`docs/realtime-map-refresh-plan.md`](docs/realtime-map-refresh-plan.md)

## Estado atual

- Autenticação com Devise + JWT;
- Usuários, organizações e memberships com perfis (`admin`, `editor`, `viewer`);
- Namespace de API versionada em `/api/v1`;
- Modelagem inicial para mapas de rede com nós, cabos e pontos de linha.
- Suporte a múltiplas conexões Zabbix (API e banco direto) por organização.
- Monitoramento operacional de cabos via `NetworkCableItem` (tráfego/status/erro/CRC) com payload realtime de classificação de enlace (`operational_state`, `traffic_level`, `alert_level`).

## Como subir o projeto

### Pré-requisitos

- Ruby (versão definida no projeto/container)
- Bundler
- Banco de dados configurado em `config/database.yml`

### Setup

```bash
bundle install
bin/rails db:prepare
```

### Rodar aplicação

```bash
bin/rails server
```

### Rodar testes

```bash
bin/rails test
```

## LDAP / Active Directory (inicial)

O login em `POST /api/v1/users/sign_in` pode autenticar via LDAP (incluindo AD) quando habilitado.

- configuração: `config/ldap.yml`
- ativação: `LDAP_ENABLED=true`
- fallback para senha local Devise: `fallback_to_database_auth`
- auto-provisionamento de usuário local: `allow_sign_up`

Variáveis comuns para AD:

- `LDAP_HOST`
- `LDAP_PORT`
- `LDAP_ENCRYPTION` (`plain`, `start_tls`, `tls`)
- `LDAP_BIND_DN`
- `LDAP_BIND_PASSWORD`
- `LDAP_SEARCH_BASE_DN`
- `LDAP_SEARCH_FILTER` (padrão `(sAMAccountName=%{login})`)
- `LDAP_ATTR_USERNAME` (padrão `sAMAccountName`)
- `LDAP_ATTR_EMAIL` (padrão `mail`)
- `LDAP_ATTR_NAME` (padrão `displayName`)

## Consulta de hosts e itens do Zabbix

Os endpoints `GET /api/v1/zabbix_connections/:zabbix_connection_id/zabbix_hosts` e `GET /api/v1/zabbix_connections/:zabbix_connection_id/zabbix_items` suportam leitura direta no banco do Zabbix quando a conexão estiver em modo `database` ou `hybrid`:

- usam as credenciais cadastradas em `ZabbixConnection` (`db_host`, `db_port`, `db_name`, `db_username`, `db_password`);
- atualmente suportam `db_adapter = postgresql` e `db_adapter = mysql`;
- parâmetros opcionais para leitura direta:
  - `limit`: limita o volume retornado (padrão `200`, máximo `1000`), disponível para hosts e itens;
  - `hostid`: filtra itens por host no banco do Zabbix (apenas em `zabbix_items`).

Quando a conexão não está com acesso a banco, os endpoints continuam retornando dados do cache local (`zabbix_hosts` e `zabbix_items`).
