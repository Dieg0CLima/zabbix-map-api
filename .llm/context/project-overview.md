# Project Overview

## Stack e runtime
- Ruby `3.4.2` (`.ruby-version`)
- Rails `8.0.4` (`Gemfile`)
- PostgreSQL principal + suporte a MySQL para leitura do banco Zabbix (`Gemfile`, `app/services/zabbix/database_connection.rb`)
- Devise + `devise-jwt` para autenticacao (`Gemfile`, `config/routes.rb`)
- `solid_cache`, `solid_queue`, `solid_cable` (`Gemfile`, `config/database.yml`)

## Escopo funcional implementado
- Autenticacao/sessao de usuario (`api/v1/users/*`, `api/v1/me`).
- Multi-organizacao com membership e papeis (`app/models/membership.rb`, `app/controllers/application_controller.rb`).
- CRUD de mapas, nos, cabos, arestas, marcadores, itens e bindings (`config/routes.rb`).
- Integracao Zabbix: conexoes, hosts, itens, historico e dropdowns (`config/routes.rb`, `app/controllers/api/v1/zabbix_*`).
- Inventario: projetos, sites, dispositivos, interfaces e vinculos com mapa (`app/controllers/api/v1/*devices*`, `*sites*`, `*network_projects*`).

## Endpoints e superficies
- V2 principal: `resources :network_maps, controller: "network_maps_v2"` em `config/routes.rb`.
- Legado preservado: `resources :legacy_network_maps, path: "legacy/network_maps"`.
- ActionCable exposto em `/cable`.

## Caracteristicas operacionais
- Escopo de organizacao resolvido por `organization_id`/`org_id` ou membership atual.
- Admin global pode operar sem contexto de organizacao em alguns fluxos.
- Escrita protegida por `require_editor_or_admin!`.

## Incertezas
- `Precisa de validacao`: matriz oficial de permissao por endpoint (docs indicam regra geral, mas nao ha tabela unica consolidada no repo).

