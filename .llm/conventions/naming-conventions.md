# Naming Conventions (inferidas)

## Ruby classes/modules
- Nome de classe em PascalCase, arquivo em snake_case.
- Namespaces por dominio: `NetworkMaps::Create`, `ZabbixItems::SummaryFetcher`.

## Services
- Acoes objetivas: `create.rb`, `update.rb`, `destroy.rb`, `fetch.rb`, `payload_builder.rb`.
- Evitar nomes genericos (`manager`, `utils`, `helper` sem contexto).

## Controllers
- Namespace `Api::V1::*`.
- Recursos V2 explicitos quando coexistem com legado (`MapNodesV2Controller`, `NetworkMapsV2Controller`).

## Campos de dominio recorrentes
- IDs externos: `external_id`.
- Metadados flexiveis: `metadata`.
- Zabbix refs: `zabbix_ref`, `zabbix_host_id`, `itemid`, `hostid`.

## Testes
- Minitest com sufixo `_test.rb`.
- Estrutura por camada em `test/models` e `test/services`.

## Incertezas
- `Precisa de validacao`: convencao oficial para prefixo de testes de request/controller (poucos exemplos encontrados).

