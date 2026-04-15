# .llm - Memoria tecnica local para agentes

## Proposito
Este diretorio guarda contexto operacional do repositorio `zabbix-map-api` para acelerar onboarding de agentes LLM e reduzir decisoes inconsistentes entre sessoes.

Ele complementa (nao substitui) a base compartilhada em `../.llm/`.

## Como usar (agentes LLM)
1. Ler `README.md` e `idea.md`.
2. Ler `context/*.md` antes de editar codigo.
3. Consultar `conventions/*.md` para manter padroes.
4. Executar tarefas seguindo `tasks/task-template.md` e `tasks/README.md`.
5. Registrar mudancas em `history/changes.md` e decisoes em `history/decisions-log.md`.
6. Quando houver decisao arquitetural relevante, criar ADR em `decisions/`.

## Responsabilidades por subdiretorio
- `context/`: entendimento tecnico atual (arquitetura, modulos, fluxos, dominio, dependencias, riscos).
- `history/`: memoria cronologica resumida de mudancas e decisoes.
- `skills/`: procedimentos reutilizaveis para execucao consistente.
- `conventions/`: padroes de codigo, nomes e principios arquiteturais.
- `decisions/`: template e registros de Architecture Decision Records.
- `tasks/`: template e instrucao de execucao de tarefas por agentes.

## Regras gerais
- Nao inventar contexto: basear em codigo e docs reais.
- Marcar incertezas com `Precisa de validacao`.
- Evitar duplicacao com docs canonicas em `docs/`.
- Referenciar caminhos reais (ex.: `config/routes.rb`).
- Atualizar este diretorio no mesmo fluxo de mudancas relevantes.
- Priorizar instrucoes acionaveis, curtas e verificaveis.

## Fontes canonicas do projeto
- `AGENTS.md`
- `README.md`
- `docs/api-contract.md`
- `docs/zabbix-map-architecture.md`
- `docs/ai-development-guidelines.md`
- `docs/ENGINEERING_GUIDELINES.md`
- `docs/architecture/service-pattern-api-v1.md`

