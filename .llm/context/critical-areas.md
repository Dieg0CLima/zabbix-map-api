# Areas Criticas para Mudancas

## 1) Escopo multi-tenant
- Qualquer busca fora de `current_organization` pode vazar dados.
- Revisar sempre uso de `current_organization.*` ou `scoped_*`.

Arquivos chave:
- `app/controllers/application_controller.rb`
- `app/controllers/concerns/organization_scoped.rb`

## 2) Superficie legado + V2
- Mudancas em mapas/cabos podem quebrar clientes antigos.
- Conferir rotas em ambos blocos de `config/routes.rb`.

## 3) Integracao Zabbix e valores live
- Evitar usar `item.lastvalue`/`item.lastclock` direto em novos endpoints.
- Priorizar `Zabbix::LiveValuesFetcher`.

## 4) Contratos do frontend
- Alteracoes de payload exigem sincronizacao com `docs/api-contract.md` e `../zabbix-map-front`.

## 5) Credenciais/segredos
- Nunca logar token/senha em texto puro.
- Preservar criptografia em `ZabbixConnection`.

