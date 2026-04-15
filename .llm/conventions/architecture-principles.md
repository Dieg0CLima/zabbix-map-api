# Architecture Principles

## 1) Multi-tenant primeiro
Toda leitura/escrita deve respeitar organizacao ativa e papeis de acesso.

## 2) Controllers finos
Controller orquestra HTTP/autorizacao; negocio fica em services.

## 3) Services orientados a caso de uso
Um service por acao significativa, com responsabilidade clara.

## 4) Modelo com invariantes locais
Validacoes de consistencia no ActiveRecord (ex.: `NetworkCable`).

## 5) Contrato de API estavel
Alterou payload/comportamento HTTP -> atualizar `docs/api-contract.md`.

## 6) Compatibilidade legada explicita
Mudancas em V2 nao devem quebrar `legacy_network_maps` sem plano.

## 7) Integracao Zabbix encapsulada
Sem acesso direto ad-hoc em controllers; usar services de `app/services/zabbix/*`.

## 8) Live values obrigatorios para metricas atuais
Em respostas de `lastvalue/lastclock`, priorizar `Zabbix::LiveValuesFetcher`.

