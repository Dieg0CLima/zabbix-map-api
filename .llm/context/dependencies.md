# Dependencias e Integracoes

## Gems principais
- `rails ~> 8.0.4`
- `pg ~> 1.1`
- `mysql2 ~> 0.5.6` (para cenarios de leitura DB Zabbix em MySQL)
- `devise` + `devise-jwt`
- `jsonapi-serializer`
- `rack-cors`
- `solid_cache`, `solid_queue`, `solid_cable`
- `puma`, `kamal`, `thruster`

Arquivo: `Gemfile`

## Banco de dados
- Desenvolvimento/Teste: PostgreSQL unico.
- Producao: `primary`, `cache`, `queue`, `cable` em `config/database.yml`.
- Variaveis relevantes: `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USERNAME`, `DB_PASSWORD`, `DB_CACHE_NAME`, `DB_QUEUE_NAME`, `DB_CABLE_NAME`.

## Integracao externa principal
- Zabbix:
  - API (modo `api`)
  - Banco direto (modo `database`)
  - Hibrido (modo `hybrid`)
- Modelo de conexao: `app/models/zabbix_connection.rb`
- Services DB/API: `app/services/zabbix/*`

## Frontend dependente
- Repo separado: `../zabbix-map-front`
- Contratos consumidos descritos em `docs/api-contract.md`.

## Ferramentas de qualidade
- Rubocop (`rubocop-rails-omakase`), config em `.rubocop.yml`
- Brakeman (`Gemfile`)
- Suite de testes Minitest (`test/`)

## Incertezas
- `Precisa de validacao`: versao e comportamento exato do cliente Zabbix HTTP (arquivo de client nao foi consolidado em um unico entrypoint obvio pelo scan rapido).

