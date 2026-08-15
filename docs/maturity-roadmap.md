# Backlog de Maturidade - Zabbix Map API

Este backlog consolida as melhorias de qualidade, contrato e operação que elevam o backend de um estado funcional para um estado mais previsivel, testavel e sustentavel.

## Status inicial

- Base funcional existente: autenticacao JWT, multi-organizacao, mapas, cabos, Zabbix e CI.
- Trabalho iniciado em 2026-06-11: centralizacao de respostas compartilhadas de `403`/`404` no `ApplicationController`, sem alterar o payload atual.

## Prioridade P0 - Contrato e previsibilidade

### P0.1 - Centralizar respostas de erro compartilhadas

Objetivo:
- reduzir inconsistencias entre controllers para erros comuns.

Escopo:
- consolidar helpers para `403` e `404` em `ApplicationController`;
- manter contrato atual enquanto o refactor avanca;
- registrar os formatos aceitos em `docs/api-contract.md` quando o contrato mudar.

Critério de pronto:
- respostas equivalentes para os mesmos cenarios de permissão e recurso ausente;
- sem duplicacao de payloads simples em controllers.

### P0.2 - Definir envelope oficial de erro da API

Objetivo:
- escolher um formato canonico para `validation`, `domain`, `forbidden`, `not_found` e `service_unavailable`.

Escopo:
- revisar `render_validation_error`, `render_domain_error` e `ApiResponse`;
- decidir se a API converge para `data/meta/errors` ou para `code/message/details` por tipo de erro;
- atualizar `docs/api-contract.md` e os testes de request.

Critério de pronto:
- uma tabela unica de erros por status HTTP.

## Prioridade P1 - Controllers finos

### P1.1 - Extrair responsabilidades residuais de controllers

Objetivo:
- deixar controllers apenas com HTTP, autorização e delegacao.

Escopo:
- mover regras remanescentes para services/query objects;
- reduzir condicionais e montagem manual de payload em controller;
- priorizar fluxos com maior acoplamento a contrato externo.

Critério de pronto:
- controllers sem logica de negocio ou query complexa inline.

### P1.2 - Consolidar escopos de organizacao

Objetivo:
- eliminar repeticao de `current_organization.*` e `scoped_*` quando o padrao for o mesmo.

Escopo:
- revisar controllers que acessam `network_maps`, `zabbix_connections`, `sites` e `devices`;
- extrair helpers/concerns onde fizer sentido;
- preservar regras especiais de admin global.

Critério de pronto:
- menor dispersao de regras de tenancy.

## Prioridade P2 - Confiança de alteração

### P2.1 - Aumentar cobertura de request specs

Objetivo:
- testar contrato HTTP de ponta a ponta nos endpoints mais usados.

Escopo:
- autenticação;
- org/tenant;
- mapas, cabos, Zabbix e fluxos administrativos;
- casos de erro e autorização.

Critério de pronto:
- mudança de contrato quebra teste antes de chegar ao frontend.

### P2.2 - Padronizar testes para caminhos legados e V2

Objetivo:
- garantir que o legado continue funcionando enquanto V2 evolui.

Escopo:
- comparar rotas e payloads principais;
- cobrir diferenças intencionais em testes separados;
- documentar depreciação quando houver.

Critério de pronto:
- coexistência de legado e V2 sem regressao silenciosa.

## Prioridade P3 - Operacao e evolucao

### P3.1 - Endurecer setup local e CI

Objetivo:
- reduzir atrito de onboarding e evitar falhas por variaveis ausentes.

Escopo:
- documentar env vars obrigatorias;
- revisar mensagens de bootstrap/teste;
- manter CI alinhado com a realidade local.

### P3.2 - Melhorar observabilidade de integrações

Objetivo:
- facilitar diagnostico de Zabbix, imports e jobs.

Escopo:
- logs estruturados;
- métricas de falha/latência;
- trilhas de execução para fluxos assíncronos.

### P3.3 - Formalizar estratégia de depreciação

Objetivo:
- reduzir custo de manter superfícies antigas sem plano.

Escopo:
- política para `legacy/*`;
- critérios para migração;
- horizonte de remoção e compatibilidade.

## Ordem recomendada de execução

1. P0.1
2. P0.2
3. P1.1
4. P1.2
5. P2.1
6. P2.2
7. P3.1
8. P3.2
9. P3.3
