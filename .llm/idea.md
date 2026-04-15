# Idea - zabbix-map-api

## Visao geral
API Rails 8 multi-organizacao para modelar mapas de rede, elementos de topologia (nos, cabos, pontos), inventario (sites/dispositivos/interfaces) e integrar dados do Zabbix (cache local + leitura direta no banco quando habilitado).

Fontes: `README.md`, `AGENTS.md`, `config/routes.rb`, `app/models/*`, `app/services/*`.

## Objetivo principal
Entregar uma API segura e previsivel para o frontend de mapas (`../zabbix-map-front`), com isolamento por organizacao e dados operacionais de monitoramento integrados ao Zabbix.

## Objetivos secundarios
- Manter compatibilidade entre superficie legada (`legacy_network_maps`) e superficie V2 (`network_maps`).
- Expor payloads estaveis para renderizacao de mapa/editor e dashboards de metricas.
- Permitir multiplas conexoes Zabbix por organizacao (`api`, `database`, `hybrid`).
- Sustentar evolucao com services dedicados e controllers finos.

## Publico-alvo
- Equipe backend Rails.
- Equipe frontend Vue/Pinia consumidora da API.
- Operacao/NOC que usa mapas e metricas para diagnostico.
- Agentes LLM que apoiam manutencao e evolucao.

## Valor esperado
### Negocio
- Melhor visibilidade de topologia e estado operacional.
- Menor tempo de diagnostico de incidentes de conectividade.
- Base para operacao multi-cliente (multi-organizacao).

### Tecnico
- Contratos de API versionados (`/api/v1`).
- Contexto de autorizacao por membership e admin global.
- Integracao Zabbix encapsulada em services.
- Memoria tecnica acumulada para reduzir regressao.

## Estagio atual
- Projeto funcional com autenticacao JWT, RBAC por membership e amplo conjunto de recursos de mapas/inventario/monitoramento.
- Suite de testes com foco maior em `test/services/*` e `test/models/*`; cobertura de request/controller aparenta limitada.
- Documentacao extensa em `docs/` com alguns trechos de "estado alvo" misturados ao "estado atual".

## Limitacoes conhecidas
- Parte da documentacao arquitetural contem recomendacoes futuras junto de estado corrente (`docs/zabbix-map-architecture.md`) e exige leitura critica.
- Possivel heterogeneidade de envelope de resposta (`render_data` vs `render json` direto em alguns controllers).
- Incerteza sobre cobertura E2E/request para todos endpoints.

## Nao e objetivo (escopo negativo)
- Nao substituir o frontend (`../zabbix-map-front`) por logica no backend.
- Nao eliminar endpoints legados sem plano de migracao e testes.
- Nao mover regra de negocio para controllers/models de forma acoplada.
- Nao expor segredos de conexao Zabbix ou credenciais sensiveis.

## Pontos que precisam de validacao
- Prioridade oficial entre superficie legada e V2 no roadmap de produto.
- Politica de deprecacao para endpoints em `legacy/*`.
- Cobertura minima de testes requerida no CI para merge.

