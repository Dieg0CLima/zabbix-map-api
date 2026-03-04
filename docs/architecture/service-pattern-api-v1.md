# API V1 Service Pattern (Use-case Oriented)

## Perfis aplicados

- **MapPopsController**: **Perfil A** (CRUD simples).
- **NetworkMapsController**: **Perfil A** (CRUD simples).
- **NetworkProjectsController**: **Perfil A** (CRUD simples sobre `NetworkMap`).
- **ZabbixConnectionsController**: **Perfil A** (CRUD simples com validações de modelo).
- **ZabbixHostsController** e **ZabbixItemsController**: recurso de leitura, sem mutação (fora de A/B/C/D), com service de fetch dedicado.

## Responsabilidades por arquivo

- `create.rb` / `update.rb` / `destroy.rb`: orquestração da mutação e ponto de entrada da ação.
- `payload_builder.rb`: apresentação serializável da resposta API.
- `fetch.rb` (hosts/items): encapsula decisão de fonte (DB Zabbix x dados persistidos locais).

## Contratos de erro

- Para os recursos acima, as invariantes principais estão no ActiveRecord.
- Controllers mapeiam `ActiveRecord::RecordInvalid` (e `RecordNotDestroyed` quando aplicável) para retorno HTTP 422 padronizado.

## Eventos/auditoria

- Não aplicável para estes recursos neste momento.
- **Não** foi criado módulo de eventos por ausência de requisito explícito.

## Invariantes e normalização

- Sem normalização complexa adicional nestes recursos.
- Sem validator/policy dedicados por ausência de regra de domínio além das validações do modelo.

## Anti-patterns evitados

- Sem lógica de negócio no controller.
- Sem service genérico do tipo `ManagerService`/`UtilsService`.
- Sem queries complexas no controller.
