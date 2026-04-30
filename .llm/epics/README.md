# Epics (.llm)

Este diretório registra épicos de produto/arquitetura em formato orientado para LLM e execução por agentes.

## Objetivo
- Preservar contexto de alto nível (porquê, escopo, riscos, decisões).
- Facilitar continuidade entre sessões sem perder critérios de aceite.
- Conectar planejamento técnico ao estado real do repositório.

## Convenção de arquivos
- Um arquivo por épico em `YYYY-MM-DD-slug.md`.
- Estrutura mínima recomendada:
  - Contexto
  - Problema
  - Objetivos
  - Escopo In/Out
  - Decisões fechadas
  - Arquitetura alvo
  - Fases de rollout
  - Checklist de entrega
  - Riscos
  - Dependências

## Estado de execução
- Atualize o mesmo arquivo com progresso por fase.
- Se houver decisão arquitetural nova, reflita também em `.llm/history/decisions-log.md`.
