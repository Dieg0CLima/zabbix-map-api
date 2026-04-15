# Coding Standards (inferidos do projeto)

## Fonte
- `docs/ENGINEERING_GUIDELINES.md`
- `docs/ai-development-guidelines.md`
- Estrutura atual em `app/controllers`, `app/services`, `app/models`

## Regras praticas
- Controllers devem ficar finos e delegar para services/builders.
- Services em `app/services/*` devem representar acoes especificas.
- Models concentram persistencia, associacoes e invariantes locais.
- Evitar logica de negocio em callbacks complexos de model.
- Evitar consultas SQL diretas em controllers.
- Tratar erros com payload consistente para o contexto do endpoint.

## Qualidade minima antes de concluir mudanca
- `bin/rails test` (escopo minimo relevante)
- `bundle exec rubocop`
- `bundle exec brakeman`

## Regras de seguranca
- Nao expor credenciais em logs/response.
- Preservar criptografia de campos sensiveis (`ZabbixConnection`).
- Sempre validar escopo de organizacao.

