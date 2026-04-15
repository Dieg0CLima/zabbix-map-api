# 2026-04-15 - Bootstrap do diretorio .llm local

## Objetivo
Criar uma base operacional local para agentes LLM no repositorio `zabbix-map-api`.

## O que foi criado
- Estrutura completa em `.llm/` (context, history, skills, conventions, decisions, tasks).
- Documentacao inicial ancorada em arquivos reais de codigo e docs do projeto.
- Skills iniciais:
  - `code-review`
  - `git-commit-workflow`
- Arquivos extras de risco e areas criticas:
  - `context/critical-areas.md`
  - `context/known-risks.md`

## Evidencias consultadas
- `config/routes.rb`
- `app/controllers/application_controller.rb`
- `app/controllers/api/v1/*`
- `app/models/*` e `app/models/zabbix/*`
- `app/services/*`
- `docs/*.md` relevantes

## Limitacoes
- Alguns pontos de produto/deprecacao nao estao fechados no codigo e foram marcados como `Precisa de validacao`.

