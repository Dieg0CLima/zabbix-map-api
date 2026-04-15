# Regras de Dominio Identificadas

## Multi-organizacao e papeis
- Todo acesso passa por organizacao ativa (`current_organization`) exceto alguns fluxos de admin global.
- Papeis de membership: `admin`, `editor`, `viewer`.
- Escritas exigem `admin`/`editor` ou `user.admin?`.

Arquivos:
- `app/controllers/application_controller.rb`
- `app/models/membership.rb`

## Mapas e topologia
- `NetworkMap` pertence a `Organization`.
- `source_type` permitido: `manual|zabbix|hybrid`.
- `active_base_layer` permitido: `standard|terrain|dark`.

Arquivo: `app/models/network_map.rb`

## Cabos
- `source_node_id` e `target_node_id` nao podem ser iguais.
- Endpoints (pops/nodes) precisam pertencer ao mesmo mapa.
- `source_pop` ou `source_node` ou `source_element` e obrigatorio.
- `external_id` unico por mapa.
- `metadata["fiber_count"]` deve ser inteiro positivo quando presente.

Arquivo: `app/models/network_cable.rb`

## Zabbix connection
- `connection_mode`: `api|database|hybrid`.
- `status`: `active|inactive|error`.
- `api_token` e `db_password` criptografados.
- Validacoes condicionais por modo (API exige `base_url`; DB exige credenciais DB).

Arquivo: `app/models/zabbix_connection.rb`

## Metricas/live values
- Para respostas com `lastvalue/lastclock`, usar `Zabbix::LiveValuesFetcher` e fallback para cache local.

Arquivo:
- `app/services/zabbix/live_values_fetcher.rb`

## Compatibilidade legada
- Endpoints legados em `legacy/network_maps` permanecem no roteamento ativo.

Arquivo:
- `config/routes.rb`

## Pontos com validacao pendente
- `Precisa de validacao`: regras completas para `users.admin` sem membership em todos endpoints (implementacao varia por controller/scope).

